-- Calls the Redis command: ZRANGEBYSCORE key min max
-- for each {key, min, max} given in the input arguments. Returns
-- the set intersection of the results
local function intersect_range_index_sets(set, tuples)
  for _, redis_key in ipairs(tuples) do
    local key, min, max = unpack(redis_key)
    local ids = redis.call('zrangebyscore', key, min, max)
    set = set_list_intersect(set, ids)
  end
  return set
end

-- Runs a query against a sorted set, extracts ids. Returns a set of ids.
local function get_custom_index_set(set, query)
  local ids = {}
  local index_strings = {}
  local sep = ':'
  local id = ''
  local key, min, max = unpack(query)
  index_strings = redis.call('zrangebylex', key, min, max)
  for _, index_string in ipairs(index_strings) do
    for str in string.gmatch(index_string, "([^"..sep.."]+)") do
      id = str
    end
    table.insert(ids, id)
  end
  set = to_set(ids)
  
  return set
end

-- Gets the hash of all the ids given. Returns the results in a
-- table, as well as any ids not found in Redis as a separate table
local function batch_hget(model, ids_set, ...)
  local res, stale_ids = {}, {}
  for id, _ in pairs(ids_set) do
    local instance = nil
    if #{...}> 0 then
      local values = redis.call('hmget', model .. ':id:' .. id, ...)
      -- HMGET returns the value in the order of the fields given. Map back to
      -- field value [field value ..]
      instance = {}
      for i, field in ipairs({...}) do
        if not values[i] then
          instance = nil
          break
        end
        table.insert(instance, field)
        table.insert(instance, values[i])
      end
    else
      -- HGETALL returns the value as field value [field value ..]
      instance = redis.call('hgetall', model .. ':id:' .. id)
    end
      -- Only add to result if entry is not stale (if query to hgetall is not empty)
    if instance and #instance > 0 then
      -- We cannot return a Lua table to Redis as a hash. Return result as a flattened
      -- array instead
      table.insert(res, id)
      table.insert(res, instance)
    else
      table.insert(stale_ids, id)
    end
  end
  return {res, stale_ids}
end

-- Returns the number of ids which exist in the given ids_set
local function batch_exists(model, ids_set)
  local id_keys = {}
  for id, _ in pairs(ids_set) do
    table.insert(id_keys, model .. ':id:' .. id)
  end

  if #id_keys == 0 then
    return 0
  end

  return redis.call('exists', unpack(id_keys))
end

-- Validate that each item in the attr_vals table is not nil
local function validate_attr_vals(attr_key, attr_vals)
  if not attr_vals or #attr_vals == 0 then
    error('Invalid value given for attribute : ' .. attr_key)
  end
  for _, val in ipairs(attr_vals) do
    if not val then
      error('Invalid value given for attribute : ' .. attr_key)
    end
  end
end

-- Validate the query conditions by checking if the attributes queried for are indexed
-- attributes. Parse query conditions into two separate tables: 
-- 1. index_sets formatted as the id set keys in Redis '#{Model.name}:#{attr_key}:#{attr_val}'
-- 2. range_index_sets formatted as a tuple {id set key, min, max} => { '#{Model.name}:#{attr_key}' min max }
local function validate_and_parse_query_conditions(hash_tag, model, index_attrs, range_index_attrs, ...) 
  -- Iterate through the arguments of the script to form the redis keys at which the
  -- indexed id sets are stored.
  local index_sets, range_index_sets = {}, {}
  local i = 1
  while i <= #arg do
    local attr_key, attr_val = arg[i], arg[i+1]
    if index_attrs[attr_key] then
      validate_attr_vals(attr_key, {attr_val})
      -- For normal index attributes, keys are stored at "#{Model.name}:#{attr_key}:#{attr_val}"
      table.insert(index_sets, model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag)
      i = i + 2
    elseif range_index_attrs[attr_key] then
      -- For range attributes, nil values are stored as normal sets
      if attr_val == "" then
        table.insert(index_sets, model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag)
        i = i + 2
      else
        local min, max = arg[i+1], arg[i+2]
        validate_attr_vals(attr_key, {min, max})
        -- For range index attributes, they are stored at "#{Model.name}:#{attr_key}"
        table.insert(range_index_sets, {model .. ':' .. attr_key .. hash_tag, min, max})
        i = i + 3
      end
    else
      error(attr_key .. ' is not an indexed attribute')
    end
  end
  return {index_sets, range_index_sets}
end

-- Validates that attributes in query are in correct order and range condition is applied only on the last attribute.
-- Returns a table {index_key, min_string, max_string} to be used for index query.
local function validate_and_parse_query_conditions_custom(hash_tag, model, index_name, custom_index_attrs, args)
  if #custom_index_attrs == 0 then
    error('Index ' .. index_name .. ' does not exist')
  end
  local sep = ':'
  local i = 1
  local j = 1
  local min, value_string_min, query_string_min = '', '', ''
  local max, value_string_max, query_string_max = '', '', ''
  local is_prev_attr_query_range = false
  while i <= #args do
    if is_prev_attr_query_range then
      error('Range can be applied to the last attribute of query only')
    end  
    local attr_key = args[i]
    if custom_index_attrs[j] == attr_key then
      min, max = args[i+1], args[i+2]
      if min then
        string.gsub (min, '(', '')
      end
      if max then
        string.gsub (max, '(', '')
      end
      if j > 1 then
        query_string_min = query_string_min .. sep
        query_string_max = query_string_max .. sep
      else
        query_string_min = query_string_min .. '['
        query_string_max = query_string_max .. '['
      end
      if min ~= '-inf' then
        value_string_min = adjust_string_length(min)
        query_string_min = query_string_min .. value_string_min
      end
      if max ~= '+inf' then
        value_string_max = adjust_string_length(max)
        query_string_max = query_string_max .. value_string_max
      else
        query_string_max = query_string_max .. '~'
      end
      if min ~= max then
        is_prev_attr_query_range = true
      end
      j = j + 1
      i = i + 3
    else
      error(attr_key .. ' in position ' .. j .. ' is not supported by index ' .. index_name)
    end
  end
  query_string_max = query_string_max .. sep .. '~'
  return {model .. sep .. 'custom_index' .. sep .. index_name .. hash_tag, query_string_min, query_string_max}
end
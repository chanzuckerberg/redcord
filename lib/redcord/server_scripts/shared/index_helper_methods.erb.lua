-- Add an id to the id set of the index attribute
local function add_id_to_index_attr(model, attr_key, attr_val, id)
  if attr_val then
    -- Call the Redis command: SADD "#{Model.name}:#{attr_name}:#{attr_val}" member ..
    redis.call('sadd', model .. ':' .. attr_key .. ':' .. attr_val, id)
  end
end

-- Remove an id from the id set of the index attribute
local function delete_id_from_index_attr(model, attr_key, attr_val, id)
  if attr_val then
    -- Call the Redis command: SREM "#{Model.name}:#{attr_name}:#{attr_val}" member ..
    redis.call('srem', model .. ':' .. attr_key .. ':' .. attr_val, id)
  end
end

-- Move an id from one id set to another for the index attribute
local function replace_id_in_index_attr(model, attr_key, prev_attr_val,curr_attr_val, id)
  -- If previous and new value differs, then modify the id sets accordingly
  if prev_attr_val ~= curr_attr_val then
    delete_id_from_index_attr(model, attr_key, prev_attr_val, id)
    add_id_to_index_attr(model, attr_key, curr_attr_val, id)
  end
end

-- Add an id to the sorted id set of the range index attribute
local function add_id_to_range_index_attr(model, attr_key, attr_val, id)
  if attr_val then
    -- Nil values of range indices are sent to Redis as an empty string. They are stored
    -- as a regular set at key "#{Model.name}:#{attr_name}:"
    if attr_val == "" then
      redis.call('sadd', model .. ':' .. attr_key .. ':' .. attr_val, id)
    else
      -- Call the Redis command: ZADD "#{Model.name}:#{attr_name}" #{attr_val} member ..,
      -- where attr_val is the score of the sorted set
      redis.call('zadd', model .. ':' .. attr_key, attr_val, id)
    end
  end
end

-- Remove an id from the sorted id set of the range index attribute
local function delete_id_from_range_index_attr(model, attr_key, attr_val, id)
  if attr_val then
    -- Nil values of range indices are sent to Redis as an empty string. They are stored
    -- as a regular set at key "#{Model.name}:#{attr_name}:"
    if attr_val == "" then
      redis.call('srem', model .. ':' .. attr_key .. ':' .. attr_val, id)
    else
      -- Call the Redis command: ZREM "#{Model.name}:#{attr_name}:#{attr_val}" member ..
      redis.call('zrem', model .. ':' .. attr_key, id)
    end
  end
end

-- Move an id from one sorted id set to another for the range index attribute
local function replace_id_in_range_index_attr(model, attr_key, prev_attr_val, curr_attr_val, id)
  if prev_attr_val ~= curr_attr_val then
    delete_id_from_range_index_attr(model, attr_key, prev_attr_val, id)
    add_id_to_range_index_attr(model, attr_key, curr_attr_val, id)
  end
end

-- Add an index record to the sorted set of the custom index
local function add_record_to_custom_index(model, attr_values, id)
  local numeric_value_length = 10
  local index_name = 'custom_indexes_main_1'
  local index_string = ''
  if attr_values then
    for i, attr_value in ipairs(attr_values) do
      if i > 1 then
        index_string = index_string .. ':'
      end
      for i=string.len(attr_value), numeric_value_length-1 do
        index_string = index_string .. '0'
      end
      index_string = index_string .. attr_value
    end

    -- Call the Redis command: SADD "#{Model.name}:#{attr_name}:#{attr_val}" member ..
    redis.call('zadd', model .. ':' .. index_name, 0, index_string .. ':' .. id)
  end
end

-- Add an id to the id set of the index attribute
local function add_id_to_index_attr(hash_tag, model, attr_key, attr_val, id)
  if attr_val then
    -- Call the Redis command: SADD "#{Model.name}:#{attr_name}:#{attr_val}" member ..
    redis.call('sadd', model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag, id)
  end
end

-- Remove an id from the id set of the index attribute
local function delete_id_from_index_attr(hash_tag, model, attr_key, attr_val, id)
  if attr_val then
    -- Call the Redis command: SREM "#{Model.name}:#{attr_name}:#{attr_val}" member ..
    redis.call('srem', model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag, id)
  end
end

-- Move an id from one id set to another for the index attribute
local function replace_id_in_index_attr(hash_tag, model, attr_key, prev_attr_val,curr_attr_val, id)
  -- If previous and new value differs, then modify the id sets accordingly
  if prev_attr_val ~= curr_attr_val then
    delete_id_from_index_attr(hash_tag, model, attr_key, prev_attr_val, id)
    add_id_to_index_attr(hash_tag, model, attr_key, curr_attr_val, id)
  end
end

-- Add an id to the sorted id set of the range index attribute
local function add_id_to_range_index_attr(hash_tag, model, attr_key, attr_val, id)
  if attr_val then
    -- Nil values of range indices are sent to Redis as an empty string. They are stored
    -- as a regular set at key "#{Model.name}:#{attr_name}:"
    if attr_val == "" then
      redis.call('sadd', model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag, id)
    else
      -- Call the Redis command: ZADD "#{Model.name}:#{attr_name}" #{attr_val} member ..,
      -- where attr_val is the score of the sorted set
      redis.call('zadd', model .. ':' .. attr_key .. hash_tag, attr_val, id)
    end
  end
end

-- Remove an id from the sorted id set of the range index attribute
local function delete_id_from_range_index_attr(hash_tag, model, attr_key, attr_val, id)
  if attr_val then
    -- Nil values of range indices are sent to Redis as an empty string. They are stored
    -- as a regular set at key "#{Model.name}:#{attr_name}:"
    if attr_val == "" then
      redis.call('srem', model .. ':' .. attr_key .. ':' .. attr_val .. hash_tag, id)
    else
      -- Call the Redis command: ZREM "#{Model.name}:#{attr_name}:#{attr_val}" member ..
      redis.call('zrem', model .. ':' .. attr_key .. hash_tag, id)
    end
  end
end

-- Move an id from one sorted id set to another for the range index attribute
local function replace_id_in_range_index_attr(hash_tag, model, attr_key, prev_attr_val, curr_attr_val, id)
  if prev_attr_val ~= curr_attr_val then
    delete_id_from_range_index_attr(hash_tag, model, attr_key, prev_attr_val, id)
    add_id_to_range_index_attr(hash_tag, model, attr_key, curr_attr_val, id)
  end
end

-- Add an index record to the sorted set of the custom index
local function add_record_to_custom_index(hash_tag, model, index_name, attr_values, id)
  local sep = ':'
  if attr_values then
    local index_string = ''
    local attr_value_string = ''
    for i, attr_value in ipairs(attr_values) do
      if i > 1 then
        index_string = index_string .. sep
      end
      attr_value_string = adjust_string_length(attr_value)
      index_string = index_string .. attr_value_string
    end
    redis.call('zadd', model .. sep .. 'custom_index' .. sep .. index_name .. hash_tag, 0, index_string .. sep .. id)
    redis.call('hset', model .. sep .. 'custom_index' .. sep .. index_name .. '_content' .. hash_tag, id, index_string .. sep .. id)
  end
end

-- Remove a record from the sorted set of the custom index
local function delete_record_from_custom_index(hash_tag, model, index_name, id)
  local sep = ':'
  local index_key = model .. sep .. 'custom_index' .. sep .. index_name
  local index_string = redis.call('hget', index_key .. '_content' .. hash_tag, id)
  if index_string then
    redis.call('zremrangebylex', index_key .. hash_tag, '[' .. index_string, '[' .. index_string)
    redis.call('hdel', index_key .. '_content' .. hash_tag, id)
  end
end

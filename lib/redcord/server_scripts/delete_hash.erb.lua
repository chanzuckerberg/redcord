--[[
EVALSHA SHA1(__FILE__) model id
> Time complexity: O(1)

Delete a hash at "#model:id:#id", and the corresponding id from the indexed 
attribute id sets.

# Return value
The number of keys deleted from Redis
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
--
--   KEYS[1] = Model.name
--   KEYS[2] = id
<%= include_lua 'shared/index_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 2 then
  error('Expected keys of be of size 2')
end

local model = KEYS[1]
local id = KEYS[2]

-- key = "#{model}:id:{id}"
local key = model .. ':id:' .. id

-- Clean up id sets for both index and range index attributes
local index_attr_keys = redis.call('smembers', model .. ':index_attrs')
if #index_attr_keys > 0 then
-- Retrieve old index attr values so we can delete them in the attribute id sets
  local attr_vals = redis.call('hmget', key, unpack(index_attr_keys))
  for i=1, #index_attr_keys do
    delete_id_from_index_attr(model, index_attr_keys[i], attr_vals[i], id)
  end
end
local range_index_attr_keys = redis.call('smembers', model .. ':range_index_attrs')
if #range_index_attr_keys > 0 then
  local attr_vals = redis.call('hmget', key, unpack(range_index_attr_keys))
  for i=1, #range_index_attr_keys do
    delete_id_from_range_index_attr(model, range_index_attr_keys[i], attr_vals[i], id)
  end
  redis.call('zrem', model .. ':id', id)
end

-- delete the actual key
return redis.call('del', key)

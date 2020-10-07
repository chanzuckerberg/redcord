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
--   KEYS = id, hash_tag
--   ARGV = Model.name index_attr_size [index_attr_key ...] [range_index_attr_key ...]
<%= include_lua 'shared/index_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 2 then
  error('Expected keys of be of size 2')
end

local model = ARGV[1]
local id, hash_tag = unpack(KEYS)

-- key = "#{model}:id:{id}"
local key = model .. ':id:' .. id

local index_attr_pos = 4
local range_attr_pos = index_attr_pos + ARGV[2]
local custom_index_pos = range_attr_pos + ARGV[3]

-- Clean up id sets for both index and range index attributes
local index_attr_keys = {unpack(ARGV, index_attr_pos, range_attr_pos - 1)}
if #index_attr_keys > 0 then
-- Retrieve old index attr values so we can delete them in the attribute id sets
  local attr_vals = redis.call('hmget', key, unpack(index_attr_keys))
  for i=1, #index_attr_keys do
    delete_id_from_index_attr(hash_tag, model, index_attr_keys[i], attr_vals[i], id)
  end
end
local range_index_attr_keys = {unpack(ARGV, range_attr_pos, custom_index_pos - 1)}
if #range_index_attr_keys > 0 then
  local attr_vals = redis.call('hmget', key, unpack(range_index_attr_keys))
  for i=1, #range_index_attr_keys do
    delete_id_from_range_index_attr(hash_tag, model, range_index_attr_keys[i], attr_vals[i], id)
  end
end
local custom_index_names = {unpack(ARGV, custom_index_pos)}
for _, index_name in ipairs(custom_index_names) do
  delete_record_from_custom_index(hash_tag, model, index_name, id)
end

-- delete the actual key
return redis.call('del', key)

--[[
EVALSHA SHA1(__FILE__) [field value ...]
> Time complexity: O(N) where N is the number of fields being set.

Create a hash with the specified fields to their respective values stored at
key when key does not exist.

# Return value
The id of the created hash as a string.
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).

--   KEYS = id hash_tag
--   ARGV = Model.name ttl index_attr_size range_index_attr_size [index_attr_key ...] [range_index_attr_key ...] attr_key attr_val [attr_key attr_val ..]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 2 then
  error('Expected keys to be of size 2')
end

local id, hash_tag = unpack(KEYS)
local model, ttl = unpack(ARGV)
local key = model .. ':id:' .. id

local index_attr_pos = 6
local range_attr_pos = index_attr_pos + ARGV[3]
local custom_attr_pos = range_attr_pos + ARGV[4]
-- Starting position of the attr_key-attr_val pairs
local attr_pos = custom_attr_pos + ARGV[5]


if redis.call('exists', key) ~= 0 then
  error(key .. ' already exists')
end

-- Forward the script arguments to the Redis command HSET.
-- Call the Redis command: HSET "#{Model.name}:id:#{id}" field value ...
redis.call('hset', key, unpack(ARGV, attr_pos))

-- Set TTL on key
if ttl and ttl ~= '-1' then
  redis.call('expire', key, ttl)
end

-- Add id value for any index and range index attributes
local attrs_hash = to_hash(unpack(ARGV, attr_pos))
local index_attr_keys = {unpack(ARGV, index_attr_pos, range_attr_pos - 1)}
if #index_attr_keys > 0 then
  for _, attr_key in ipairs(index_attr_keys) do
    add_id_to_index_attr(hash_tag, model, attr_key, attrs_hash[attr_key], id)
  end
end
local range_index_attr_keys = {unpack(ARGV, range_attr_pos, custom_attr_pos - 1)}
if #range_index_attr_keys > 0 then
  for _, attr_key in ipairs(range_index_attr_keys) do
    add_id_to_range_index_attr(hash_tag, model, attr_key, attrs_hash[attr_key], id)
  end
end

local custom_index_attr_keys = {unpack(ARGV, custom_attr_pos, attr_pos - 1)}
local i = 1
while i < #custom_index_attr_keys do
  local index_name, attrs_num = custom_index_attr_keys[i], custom_index_attr_keys[i+1]
  local attr_values = {}
  for j, attr_key in ipairs({unpack(custom_index_attr_keys, i + 2, i + attrs_num + 1)}) do
    attr_values[j] = attrs_hash[attr_key]
  end
  add_record_to_custom_index(hash_tag, model, index_name, attr_values, id)
  i = i + 2 + attrs_num
end

return nil

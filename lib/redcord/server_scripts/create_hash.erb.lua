--[[
EVALSHA SHA1(__FILE__) [field value ...]
> Time complexity: O(N) where N is the number of fields being set.

Create a hash with the specified fields to their respective values stored at
key when key does not exist.

# Return value
nil
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).

--   KEYS[1] = Model.name
--   KEYS[2] = id
--   ARGV[1...2N] = attr_key attr_val [attr_key attr_val ..]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 2 then
  error('Expected keys to be of size 2')
end
if #ARGV % 2 ~= 0 then
  error('Expected an even number of arguments')
end

local model = KEYS[1]
local id = KEYS[2]
local ttl = redis.call('get', model .. ':ttl')
local key = model .. ':id:' .. id

if redis.call('exists', key) ~= 0 then
  error(key .. ' already exists')
end

-- Forward the script arguments to the Redis command HSET.
-- Call the Redis command: HSET "#{Model.name}:id:#{id}" field value ...
redis.call('hset', key, unpack(ARGV))

-- Set TTL on key
if ttl and ttl ~= '-1' then
  redis.call('expire', key, ttl)
end

-- Add id value for any index and range index attributes
local attrs_hash = to_hash(ARGV)
local index_attr_keys = redis.call('smembers', model .. ':index_attrs')
if #index_attr_keys > 0 then
  for _, attr_key in ipairs(index_attr_keys) do
    add_id_to_index_attr(model, attr_key, attrs_hash[attr_key], id)
  end
end
local range_index_attr_keys = redis.call('smembers', model .. ':range_index_attrs')
if #range_index_attr_keys > 0 then
  for _, attr_key in ipairs(range_index_attr_keys) do
    add_id_to_range_index_attr(model, attr_key, attrs_hash[attr_key], id)
  end
end
return nil

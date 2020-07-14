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

--   KEYS[1] = Model.name
--   ARGV[1...2N] = attr_key attr_val [attr_key attr_val ..]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 1 then
  error('Expected keys to be of size 1')
end
if #ARGV % 2 ~= 0 then
  error('Expected an even number of arguments')
end

local model = KEYS[1]

-- Call the Redis command: INCR "#{Model.name}:id_seq". If "#{Model.name}:id_seq" does
-- not exist, the command returns 0. It errors if the id_seq overflows a 64 bit
-- signed integer.
redis.call('incr', model .. ':id_seq')

-- The Lua version used by Redis does not support 64 bit integers:
--   https://github.com/antirez/redis/issues/5261
-- We ignore the integer response from INCR and use the string response from
-- the GET/MGET command.
local id, ttl = unpack(redis.call('mget', model .. ':id_seq', model .. ':ttl'))
local key = model .. ':id:' .. id

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
attrs_hash['id'] = id
if #range_index_attr_keys > 0 then
  for _, attr_key in ipairs(range_index_attr_keys) do
    add_id_to_range_index_attr(model, attr_key, attrs_hash[attr_key], id)
  end
end
return id

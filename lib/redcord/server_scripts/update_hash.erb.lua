--[[
EVALSHA SHA1(__FILE__) model id [field value ...]
> Time complexity: O(N) where N is the number of fields being set.

Update a hash with the specified fields to their respective values stored at
"model":id:"id", and modify the indexed attribute id sets accordingly. Refresh 
the ttl if a model's ttl exists and is set to a value other than -1

# Return value
nil
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).
--
--   KEYS[1] = redcord_instance.class.name
--   KEYS[2] = redcord_instance.id
--   KEYS[3] = hash_tag
--   ARGV[1...2N] = attr_key attr_val [attr_key attr_val ..]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

if #KEYS ~= 3 then
  error('Expected keys of be of size 3')
end
if #ARGV % 2 ~= 0 then
  error('Expected an even number of arguments')
end

local model = KEYS[1]
local id = KEYS[2]

-- key = "#{model}:id:{id}"
local key = model .. ':id:' .. id

-- If there a delete operation (including expiring due to TTL) happened before
-- the update in another thread, the client might still send an update command
-- to the server. To avoid saving partial data, we reject this update call with
-- an error.
if redis.call('exists', key) == 0 then
  error(key .. ' has been deleted')
end

-- Modify the id sets for any indexed attributes
local attrs_hash = to_hash(ARGV)
local indexed_attr_keys = redis.call('smembers', model .. ':index_attrs')
if #indexed_attr_keys > 0 then
  -- Get the previous and new values for indexed attributes
  local prev_attrs = redis.call('hmget', key, unpack(indexed_attr_keys))
  for i, attr_key in ipairs(indexed_attr_keys) do
    local prev_attr_val, curr_attr_val = prev_attrs[i], attrs_hash[attr_key]
    -- Skip attr values not present in the argument hash
    if curr_attr_val then
      replace_id_in_index_attr(model, attr_key, prev_attr_val, curr_attr_val, id)
    end
  end
end
local range_index_attr_keys = redis.call('smembers', model .. ':range_index_attrs')
if #range_index_attr_keys > 0 then
  -- Get the previous and new values for indexed attributes
  local prev_attrs = redis.call('hmget', key, unpack(range_index_attr_keys))
  for i, attr_key in ipairs(range_index_attr_keys) do
    local prev_attr_val, curr_attr_val = prev_attrs[i], attrs_hash[attr_key]
    -- Skip attr values not present in the argument hash
    if curr_attr_val then
      replace_id_in_range_index_attr(model, attr_key, prev_attr_val, curr_attr_val, id)
    end
  end
end

-- Forward the script arguments to the Redis command HSET and update the args.
-- Call the Redis command: HSET key [field value ...]
redis.call('hset', key, unpack(ARGV))

-- Call the Redis command: GET "#{Model.name}:ttl"
local ttl = redis.call('get', model .. ':ttl')

if ttl then
  if ttl == '-1' then
    -- Persist the object if the ttl is set to -1
    redis.call('persist', key)
  else
    -- Reset the TTL for this object. We do this manually becaues altering the
    -- field value of a hash with HSET, etc. will leave the TTL
    -- untouched: https://redis.io/commands/expire
    redis.call('expire', key, ttl)
  end
end
return nil

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
--   KEYS = redcord_instance.id hash_tag
--   ARGV = Model.name ttl index_attr_size range_index_attr_size custom_index_attrs_flat_size [index_attr_key ...] [range_index_attr_key ...]
--          [custom_index_name attrs_size [custom_index_attr_key ...] ...] attr_key attr_val [attr_key attr_val ..]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

if #KEYS ~= 2 then
  error('Expected keys of be of size 2')
end

local model, ttl = unpack(ARGV)
local id, hash_tag = unpack(KEYS)

local index_attr_pos = 6
local range_attr_pos = index_attr_pos + ARGV[3]
local custom_attr_pos = range_attr_pos + ARGV[4]
-- Starting position of the attr_key-attr_val pairs
local attr_pos = custom_attr_pos + ARGV[5]

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
local attrs_hash = to_hash(unpack(ARGV, attr_pos))
local indexed_attr_keys = {unpack(ARGV, index_attr_pos, range_attr_pos - 1)}
if #indexed_attr_keys > 0 then
  -- Get the previous and new values for indexed attributes
  local prev_attrs = redis.call('hmget', key, unpack(indexed_attr_keys))
  for i, attr_key in ipairs(indexed_attr_keys) do
    local prev_attr_val, curr_attr_val = prev_attrs[i], attrs_hash[attr_key]
    -- Skip attr values not present in the argument hash
    if curr_attr_val then
      replace_id_in_index_attr(hash_tag, model, attr_key, prev_attr_val, curr_attr_val, id)
    end
  end
end
local range_index_attr_keys = {unpack(ARGV, range_attr_pos, custom_attr_pos - 1)}
if #range_index_attr_keys > 0 then
  -- Get the previous and new values for indexed attributes
  local prev_attrs = redis.call('hmget', key, unpack(range_index_attr_keys))
  for i, attr_key in ipairs(range_index_attr_keys) do
    local prev_attr_val, curr_attr_val = prev_attrs[i], attrs_hash[attr_key]
    -- Skip attr values not present in the argument hash
    if curr_attr_val then
      replace_id_in_range_index_attr(hash_tag, model, attr_key, prev_attr_val, curr_attr_val, id)
    end
  end
end

-- Forward the script arguments to the Redis command HSET and update the args.
-- Call the Redis command: HSET key [field value ...]
redis.call('hset', key, unpack(ARGV, attr_pos))

-- Update custom indexes
local updated_hash = to_hash(unpack(redis.call('hgetall', key)))
local custom_index_attr_keys = {unpack(ARGV, custom_attr_pos, attr_pos - 1)}
local i = 1
while i < #custom_index_attr_keys do
  local index_name, attrs_num = custom_index_attr_keys[i], custom_index_attr_keys[i+1]
  local attr_values = {}
  for j, attr_key in ipairs({unpack(custom_index_attr_keys, i + 2, i + attrs_num + 1)}) do
    attr_values[j] = updated_hash[attr_key]
  end
  delete_record_from_custom_index(hash_tag, model, index_name, id)
  add_record_to_custom_index(hash_tag, model, index_name, attr_values, id)
  i = i + 2 + attrs_num
end

-- Call the Redis command: GET "#{Model.name}:ttl"
if ttl == '-1' then
  -- Persist the object if the ttl is set to -1
  redis.call('persist', key)
else
  -- Reset the TTL for this object. We do this manually becaues altering the
  -- field value of a hash with HSET, etc. will leave the TTL
  -- untouched: https://redis.io/commands/expire
  redis.call('expire', key, ttl)
end
return nil

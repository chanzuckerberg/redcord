--[[
EVALSHA SHA1(__FILE__) model id index_name
> Time complexity: O(1)

Add a record id to the its index set.

# Return value
nil
--]]
--   KEYS[1] = redcord_instance.class.name
--   KEYS[2] = redcord_instance.id
--   ARGV[1] = index_name
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/index_helper_methods' %>

if #KEYS ~= 2 then
  error('Expected keys of be of size 2')
end
if #ARGV ~= 1 then
  error('Expected arguments of size 1')
end

local model = KEYS[1]
local id = KEYS[2]
local index_name = ARGV[1]

-- key = "#{model}:id:{id}"
local key = model .. ':id:' .. id

-- If there a delete operation (including expiring due to TTL) happened before
-- the update in another thread, the client might still send an update command
-- to the server. To avoid saving partial data, we reject this update call with
-- an error.
if redis.call('exists', key) == 0 then
  error(key .. ' has been deleted')
end

local index_val = redis.call('hget', key, index_name)

if redis.call('sismember', model .. ':index_attrs', index_name) == 1 then
  add_id_to_index_attr(model, index_name, index_val, id)
elseif redis.call('sismember', model .. ':range_index_attrs', index_name) == 1 then
  add_id_to_range_index_attr(model, index_name, index_val, id)
end

return nil

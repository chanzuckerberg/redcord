--[[
EVALSHA SHA1(__FILE__) model id
> Time complexity: O(N) where N is the number of ids with these attributes

Query for all model instances that have the given attribute values or value ranges.
Return an error if an attribute is not an index.

# Return value
A hash of id:model of all the ids that match the attribute value given. 
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).
--
--   KEYS[1] = Model.name
--   ARGV[1...2N] = attr_key attr_val [attr_key attr_val ..]
--
--   For equality query conditions, key value pairs are expected to appear in
--   the ARGV array as [attr_key, attr_val]
--   For range query conditions, key value pairs are expected to appear in the
--   ARGV array as [key min_val max_val]
<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/query_helper_methods' %>

-- Validate input to script before making Redis db calls
if #KEYS ~= 1 then
  error('Expected keys to be of size 1')
end
local function validate_attr_vals(attr_key, attr_vals)
  for _, val in ipairs(attr_vals) do
    if not val then
      error('Invalid value given for attribute : ' .. attr_key)
    end
  end
end

local model = KEYS[1]

local index_attrs = to_set(redis.call('smembers', model .. ':index_attrs'))
local range_index_attrs = to_set(redis.call('smembers', model .. ':range_index_attrs'))
-- Iterate through the arguments of the script to form the redis keys at which the
-- indexed id sets are stored.
local index_sets, range_index_sets = {}, {}
local i = 1
while i <= #ARGV do
  local attr_key, attr_val = ARGV[i], ARGV[i+1]
  if index_attrs[attr_key] then
    validate_attr_vals(attr_key, {attr_val})
    -- For normal index attributes, keys are stored at "#{Model.name}:#{attr_key}:#{attr_val}"
    table.insert(index_sets, model .. ':' .. attr_key .. ':' .. attr_val)
    i = i + 2
  elseif range_index_attrs[attr_key] then
    -- For range attributes, nil values are stored as normal sets
    if attr_val == "" then
      table.insert(index_sets, model .. ':' .. attr_key .. ':' .. attr_val)
      i = i + 2
    else
      local min, max = ARGV[i+1], ARGV[i+2]
      validate_attr_vals(attr_key, {min, max})
      -- For range index attributes, they are stored at "#{Model.name}:#{attr_key}"
      table.insert(range_index_sets, {model .. ':' .. attr_key, min, max})
      i = i + 3
    end
  else
    error(attr_key .. ' is not an indexed attribute')
  end
end

-- Get all ids which have the corresponding attribute values.
local ids_set = nil
-- For normal sets, Redis has SINTER built in to return the set intersection
if #index_sets > 0 then
   ids_set = to_set(redis.call('sinter', unpack(index_sets)))
end
-- For sorted sets, call helper function zinter_zrangebyscore, which calls
-- ZRANGEBYSCORE for each {redis_key, min, max} tuple and returns the set intersection
if #range_index_sets then
  ids_set = intersect_range_index_sets(ids_set, range_index_sets)
end

-- Query for the hashes for all ids in the set intersection
local res, stale_ids = unpack(batch_hgetall(model, ids_set))

-- Delete any stale ids which are no longer in redis from the id sets.
-- This can happen if an entry was auto expired due to ttl, but not removed up yet
-- from the id sets.
if #stale_ids > 0 then
  for _, key in ipairs(index_sets) do
    redis.call('srem', key, unpack(stale_ids))
  end
  for _, key in ipairs(range_index_sets) do
    local redis_key = key[1]
    redis.call('zrem', redis_key, unpack(stale_ids))
  end
end

return res

--[[
EVALSHA SHA1(__FILE__) model id
> Time complexity: O(N) where N is the number of ids with these attributes

Query for all model instances that have the given attribute values or value ranges.
Return an error if an attribute is not an index.

# Return value
A hash of id:model of all the ids that match the query conditions given.
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).
--
--   KEYS[1] = Model.name attr_key attr_val [attr_key attr_val ..] hash_tag
--   ARGV[1...N] = attr_key [attr_key ..]
--
--   For equality query conditions, key value pairs are expected to appear in
--   the KEYS array as [attr_key, attr_val]
--   For range query conditions, key value pairs are expected to appear in the
--   KEYS array as [key min_val max_val]
--
--   The ARGV array is used to specify specific fields to select for each record. If
--   the ARGV array is empty, then all fields will be retrieved.

<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/query_helper_methods' %>

if #KEYS < 4 then
  error('Expected keys to be at least of size 3')
end

local model = KEYS[1]
local index_sets, range_index_sets = unpack(validate_and_parse_query_conditions(model, KEYS))

-- Get all ids which have the corresponding attribute values.
local ids_set = nil
-- For normal sets, Redis has SINTER built in to return the set intersection
if #index_sets > 0 then
   ids_set = to_set(redis.call('sinter', unpack(index_sets)))
end
-- For sorted sets, call helper function zinter_zrangebyscore, which calls
-- ZRANGEBYSCORE for each {redis_key, min, max} tuple and returns the set intersection
if #range_index_sets > 0 then
  ids_set = intersect_range_index_sets(ids_set, range_index_sets)
end

-- Query for the hashes for all ids in the set intersection
local res, stale_ids = unpack(batch_hget(model, ids_set, ARGV))

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

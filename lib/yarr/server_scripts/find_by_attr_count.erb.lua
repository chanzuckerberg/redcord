--[[
EVALSHA SHA1(__FILE__) model id
> Time complexity: O(N) where N is the number of ids with these attributes

Query for all model instances that have the given attribute values or value ranges.
Return an error if an attribute is not an index.

# Return value
An integer number of records that match the query conditions given.
--]]

-- The arguments can be accessed by Lua using the KEYS global variable in the
-- form of a one-based array (so KEYS[1], KEYS[2], ...).
-- All the additional arguments should not represent key names and can be
-- accessed by Lua using the ARGV global variable, very similarly to what
-- happens with keys (so ARGV[1], ARGV[2], ...).
--
--   KEYS[1] = Model.name attr_key attr_val [attr_key attr_val ..]
--
--   For equality query conditions, key value pairs are expected to appear in
--   the KEYS array as [attr_key, attr_val]
--   For range query conditions, key value pairs are expected to appear in the
--   KEYS array as [key min_val max_val]

<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/query_helper_methods' %>

if #KEYS < 3 then
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

-- Get the number of records which satisfy the query conditions.
-- We do not delete stale ids as part of this function call because we do not have
-- the list of ids which don't exist. The Redis command EXISTS key [key ...] is an O(1)
-- operation that only returns the count of ids that exist. Getting the list of ids that
-- don't exist would be an O(N) operation.
return batch_exists(model, ids_set)

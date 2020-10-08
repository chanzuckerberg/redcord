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
--   KEYS[1] = hash_tag
--   ARGV = Model.name num_index_attr num_range_index_attr num_query_conditions ...
--
--   For equality query conditions, key value pairs are expected to appear in
--   the KEYS array as [attr_key, attr_val]
--   For range query conditions, key value pairs are expected to appear in the
--   KEYS array as [key min_val max_val]

<%= include_lua 'shared/lua_helper_methods' %>
<%= include_lua 'shared/query_helper_methods' %>

if #KEYS ~=1 then
  error('Expected keys to be of size 1')
end

local model = ARGV[1]

local index_name = ARGV[2]
local index_attr_pos = 6
local range_attr_pos = index_attr_pos + ARGV[3]
local custom_attr_pos = range_attr_pos + ARGV[4]
local query_cond_pos = custom_attr_pos + ARGV[5]

-- Get all ids which have the corresponding attribute values.
local ids_set = nil

if index_name == '' then
  local index_sets, range_index_sets = unpack(validate_and_parse_query_conditions(
    KEYS[1],
    model,
    to_set({unpack(ARGV, index_attr_pos, range_attr_pos - 1)}),
    to_set({unpack(ARGV, range_attr_pos, custom_attr_pos - 1)}),
    unpack(ARGV, query_cond_pos)
  ))

  -- For normal sets, Redis has SINTER built in to return the set intersection
  if #index_sets > 0 then
    ids_set = to_set(redis.call('sinter', unpack(index_sets)))
  end
  -- For sorted sets, call helper function zinter_zrangebyscore, which calls
  -- ZRANGEBYSCORE for each {redis_key, min, max} tuple and returns the set intersection
  if #range_index_sets > 0 then
    ids_set = intersect_range_index_sets(ids_set, range_index_sets)
  end
else
  local custom_index_attrs = {unpack(ARGV, custom_attr_pos, query_cond_pos - 1)}
  local custom_index_query = validate_and_parse_query_conditions_custom(
    KEYS[1],
    model,
    index_name,
    custom_index_attrs,
    {unpack(ARGV, query_cond_pos)}
  )
  if #custom_index_query > 0 then
    ids_set = get_custom_index_set(ids_set, custom_index_query)
  else
    ids_set = {}
  end
end
-- Get the number of records which satisfy the query conditions.
-- We do not delete stale ids as part of this function call because we do not have
-- the list of ids which don't exist. The Redis command EXISTS key [key ...] is an O(1)
-- operation that only returns the count of ids that exist. Getting the list of ids that
-- don't exist would be an O(N) operation.
return batch_exists(model, ids_set)

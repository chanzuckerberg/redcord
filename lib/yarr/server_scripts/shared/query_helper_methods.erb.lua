-- Calls the Redis command: ZRANGEBYSCORE key min max
-- for each {key, min, max} given in the input arguments. Returns
-- the set intersection of the results
local function intersect_range_index_sets(set, tuples)
  for _, redis_key in ipairs(tuples) do
    local key, min, max = unpack(redis_key)
    local ids = redis.call('zrangebyscore', key, min, max)
    set = set_list_intersect(set, ids)
  end
  return set
end

-- Gets the hash of all the ids given. Returns the results in a
-- table, as well as any ids not found in Redis as a separate table
local function batch_hgetall(model, ids_set)
  local res, stale_ids = {}, {}
  for id, _ in pairs(ids_set) do
    local instance = redis.call('hgetall', model .. ':id:' .. id)
    -- Only add to result if entry is not stale (if query to hgetall is not empty)
    if #instance > 0 then
      -- We cannot return a Lua table to Redis as a hash. Return result as a flattened
      -- array instead
      table.insert(res, id)
      table.insert(res, instance)
    else
      table.insert(stale_ids, id)
    end
  end
  return {res, stale_ids}
end

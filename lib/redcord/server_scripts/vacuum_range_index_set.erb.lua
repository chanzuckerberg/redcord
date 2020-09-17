local model = KEYS[1]
local attribute = ARGV[1]
local cursor = ARGV[2]

local range_index_set_key = model .. ':' .. attribute
-- zscan
local new_cursor, set_members = unpack(redis.call('zscan', range_index_set_key, cursor))

for _, id in ipairs(set_members) do
  if redis.call('exists', model .. ':id:' .. id) == 0 then
    redis.call('zrem', range_index_set_key, id)
  end
end

return new_cursor

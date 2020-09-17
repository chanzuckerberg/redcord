
local model = KEYS[1]
local attribute = ARGV[1]
local cursor = ARGV[2]

local pattern = model .. ':' .. attribute .. '*'
-- Find index set keys
local new_cursor, index_set_keys = unpack(redis.call('scan', cursor, 'match', pattern))

-- expire value
for _, key in ipairs(index_set_keys) do
  local ids = redis.call('smembers', key)
  for _, id in ipairs(ids) do
    if redis.call('exists', model .. ':id:' .. id) == 0 then
      redis.call('srem', key, id)
    end
  end
end

return new_cursor

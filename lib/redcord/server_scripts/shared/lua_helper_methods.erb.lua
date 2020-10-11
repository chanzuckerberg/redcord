-- Helper function to convert argument array to hash set
local function to_hash(...)
  local hash = {}
  for i=1, #arg, 2 do
    hash[arg[i]] = arg[i+1]
  end
  return hash
end

-- Helper function to convert list to set
local function to_set(list)
  local set = {}
  if not list then return set end
  for _, item in ipairs(list) do
    set[item] = true
  end
  return set
end

-- Helper function to compute the intersection of the given set and list.
local function set_list_intersect(set, list)
  -- A nil set means that no items have been added to the set yet. If so,
  -- we can just return the given list as a set
  if not set then return to_set(list) end
  local set_intersect = {}
  for _, item in ipairs(list) do
    if set[item] then
      set_intersect[item] = true
    end
  end
  return set_intersect
end

-- Helper function to transform attribute values so that they become comparable as strings
local function adjust_string_length(value)
  if value == '' or value == nil then
    return '!'
  end
  if string.sub(value, 1, 1) == '-' then
    error("Custom index currently doesn't support negative values")
  end
  local whole_digits_count = 19
  local res = string.rep('0', whole_digits_count - string.len(value)) .. value
  if string.len(res) > whole_digits_count then
    error("Custom index can't be used if string representation of whole part of attribute value is longer than " .. 
           whole_digits_count .. ' characters')
  end
  return res
end

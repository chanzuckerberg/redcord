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

local function adjust_string_length(value)
  if value == '' or value == nil then
    return '!'
  end
  local whole_digits_count = 10
  local decimal_digits_count = 4
  local sep = '.'
  local parts = {}
  for part in string.gmatch(value, "([^"..sep.."]+)") do
    table.insert(parts, part)
  end
  local res = string.rep('0', whole_digits_count - string.len(parts[1])) .. parts[1]
  if string.len(res) > whole_digits_count then
    error("Custom index can't be used if string representation of whole part of attribute value is longer than " .. 
           whole_digits_count .. ' characters')
  end
  if parts[2] then
    local decimal_part = string.sub(parts[2], 1, decimal_digits_count) .. 
      string.rep('0', decimal_digits_count - string.len(parts[2]))
    res = res .. sep .. decimal_part
  end
  return res
end
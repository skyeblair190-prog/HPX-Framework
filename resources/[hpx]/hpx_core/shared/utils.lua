HPX = HPX or {}

function HPX.copy(value)
  if type(value) ~= 'table' then return value end
  local out = {}
  for k,v in pairs(value) do out[k] = HPX.copy(v) end
  return out
end

function HPX.merge(base, extra)
  local out = HPX.copy(base or {})
  for k,v in pairs(extra or {}) do
    if type(v) == 'table' and type(out[k]) == 'table' then
      out[k] = HPX.merge(out[k], v)
    else
      out[k] = HPX.copy(v)
    end
  end
  return out
end

function HPX.clamp(value, min, max)
  value = tonumber(value) or min
  return math.max(min, math.min(max, value))
end

function HPX.round(value, decimals)
  local power = 10 ^ (decimals or 0)
  return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

function HPX.isEmpty(value)
  return value == nil or value == '' or (type(value) == 'table' and next(value) == nil)
end

function HPX.trace(...)
  if HPXConfig and HPXConfig.debug then
    print(('[HPX] %s'):format(table.concat({...}, ' ')))
  end
end

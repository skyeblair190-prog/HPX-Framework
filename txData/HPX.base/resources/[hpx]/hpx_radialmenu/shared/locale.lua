Locale = {}
Locale.__index = Locale

local function flatten(target, source, prefix)
  for key, value in pairs(source) do
    local path = prefix and (prefix .. '.' .. key) or key
    if type(value) == 'table' then
      flatten(target, value, path)
    else
      target[path] = value
    end
  end
end

function Locale.new(_, opts)
  local self = setmetatable({}, Locale)
  self.phrases = {}
  self.warnOnMissing = opts and opts.warnOnMissing
  flatten(self.phrases, (opts and opts.phrases) or {})
  return self
end

function Locale:t(key, subs)
  local phrase = self.phrases[key]
  if not phrase then
    if self.warnOnMissing then print(('[locale] missing phrase "%s"'):format(key)) end
    return key
  end
  if subs then
    phrase = phrase:gsub('%%{(.-)}', function(name)
      local value = subs[name]
      return value ~= nil and tostring(value) or ('%{' .. name .. '}')
    end)
  end
  return phrase
end

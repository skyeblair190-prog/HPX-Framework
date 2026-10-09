function HPXGetIdentifiers(source)
  local out = {}
  for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
    local kind, value = identifier:match('([^:]+):(.+)')
    if kind then out[kind] = value end
  end
  return out
end

function HPXGetLicense(source)
  local ids = HPXGetIdentifiers(source)
  return ids.license or ids.license2 or ids.fivem
end

function HPXGetDiscord(source)
  return HPXGetIdentifiers(source).discord
end

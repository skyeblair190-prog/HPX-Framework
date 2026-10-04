local calls = {}
local nextId = 0

lib.callback.register('hpx:dispatch:create', function(source, data)
  if type(data) ~= 'table' then return nil end
  nextId += 1
  local call = {
    id = nextId,
    source = source,
    code = tostring(data.code or '10-99'),
    title = tostring(data.title or 'Emergency'),
    description = tostring(data.description or ''),
    coords = data.coords,
    created = os.time()
  }
  calls[nextId] = call
  TriggerClientEvent('hpx:dispatch:new', -1, call)
  return call
end)

lib.callback.register('hpx:dispatch:list', function()
  local out = {}
  for _, call in pairs(calls) do out[#out + 1] = call end
  table.sort(out, function(a,b) return a.id > b.id end)
  return out
end)

exports('CreateCall', function(source, data)
  return lib.callback.await('hpx:dispatch:create', source, data)
end)

local MAX_CALLS <const> = 100
local COOLDOWN <const> = 2000

local calls, order, lastCreated = {}, {}, {}
local nextId = 0

local function clean(value, max, fallback)
  return tostring(value or fallback):sub(1, max)
end

local function createCall(source, data)
  if type(data) ~= 'table' then return nil end

  nextId = nextId + 1
  local call = {
    id = nextId,
    source = source,
    code = clean(data.code, 16, '10-99'),
    title = clean(data.title, 64, 'Emergency'),
    description = clean(data.description, 256, ''),
    created = os.time()
  }

  local coords = data.coords
  if type(coords) == 'table' or type(coords) == 'vector3' then
    if type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number' then
      call.coords = vector3(coords.x, coords.y, coords.z)
    end
  end

  calls[nextId] = call
  order[#order + 1] = nextId
  if #order > MAX_CALLS then
    calls[table.remove(order, 1)] = nil
  end

  TriggerClientEvent('hpx:dispatch:new', -1, call)
  return call
end

lib.callback.register('hpx:dispatch:create', function(source, data)
  local now = GetGameTimer()
  if lastCreated[source] and now - lastCreated[source] < COOLDOWN then return nil end
  lastCreated[source] = now
  return createCall(source, data)
end)

lib.callback.register('hpx:dispatch:list', function()
  local out = {}
  for _, call in pairs(calls) do out[#out + 1] = call end
  table.sort(out, function(a, b) return a.id > b.id end)
  return out
end)

AddEventHandler('playerDropped', function()
  lastCreated[source] = nil
end)

exports('CreateCall', createCall)

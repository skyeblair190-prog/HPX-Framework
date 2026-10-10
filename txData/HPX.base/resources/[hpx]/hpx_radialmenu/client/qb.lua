QBCore = { Functions = {} }

function QBCore.Functions.Notify(message, notifyType, duration)
  exports.hpx_notify:Notify(message, notifyType, duration)
end

function QBCore.Functions.NormalizePlayerData(data)
  data = type(data) == 'table' and data or {}
  if type(data.job) ~= 'table' then data.job = { name = 'unemployed' } end
  if type(data.metadata) ~= 'table' then data.metadata = {} end
  return data
end

function QBCore.Functions.GetPlayerData()
  local ok, data = pcall(function() return exports.hpx_core:GetPlayerData() end)
  return QBCore.Functions.NormalizePlayerData(ok and data or nil)
end

function QBCore.Functions.GetPlate(vehicle)
  if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
  return (GetVehicleNumberPlateText(vehicle):gsub('^%s+', ''):gsub('%s+$', ''))
end

function QBCore.Functions.GetPlayersFromCoords(coords, distance)
  coords = coords or GetEntityCoords(PlayerPedId())
  distance = distance or 5.0
  local players = {}
  for _, player in ipairs(GetActivePlayers()) do
    if #(GetEntityCoords(GetPlayerPed(player)) - coords) <= distance then
      players[#players + 1] = player
    end
  end
  return players
end

function QBCore.Functions.GetClosestPlayer(coords)
  coords = coords or GetEntityCoords(PlayerPedId())
  local closest, closestDistance = -1, -1
  for _, player in ipairs(GetActivePlayers()) do
    if player ~= PlayerId() then
      local distance = #(GetEntityCoords(GetPlayerPed(player)) - coords)
      if closestDistance == -1 or distance < closestDistance then
        closest, closestDistance = player, distance
      end
    end
  end
  return closest, closestDistance
end

function QBCore.Functions.GetClosestVehicle(coords)
  coords = coords or GetEntityCoords(PlayerPedId())
  local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
  if vehicle == 0 then return -1, -1 end
  return vehicle, #(GetEntityCoords(vehicle) - coords)
end

function QBCore.Functions.TriggerCallback(name, cb, ...)
  local args = { ... }
  CreateThread(function() cb(lib.callback.await(name, false, table.unpack(args))) end)
end

local Config <const> = HPXGarages
local Garages <const> = Config.garages

local MESSAGES <const> = {
  generic = 'Something went wrong.',
  busy = 'Please wait a moment.',
  denied = 'You cannot use this garage.',
  invalid = 'Invalid request.',
  not_found = 'Vehicle not found.',
  not_owned = 'You cannot access that vehicle.',
  not_available = 'That vehicle is not available here.',
  not_impounded = 'That vehicle is not at the depot.',
  in_world = 'That vehicle is already out.',
  no_funds = 'You cannot afford the fee.',
  too_far = 'Move the vehicle closer.',
  no_space = 'Something is blocking the spawn point.',
  stored = 'Vehicle stored.',
  stop = 'Stop the vehicle first.',
  wrong_type = 'This garage cannot hold that vehicle.',
  not_vehicle = 'Get in a vehicle to store it.',
  spawn_failed = 'The vehicle failed to load. Check the depot.',
}

local TEXT <const> = {
  garage = '[E] Open Garage',
  depot = '[E] Open Depot',
  park = '[E] Store Vehicle',
}

local blips, hint = {}, nil
local isOpen, isBusy, current = false, false, nil

local function notify(message, kind)
  if GetResourceState('hpx_notify') == 'started' then
    exports.hpx_notify:Notify(message, kind, 5000)
  else
    lib.notify({ description = message, type = kind })
  end
end

local function setHint(text)
  if text == hint then return end
  hint = text
  if text then lib.showTextUI(text) else lib.hideTextUI() end
end

local function resolveHash(model)
  return tonumber(model) or joaat(model)
end

local function matchesType(hash, vehicleType)
  local class = GetVehicleClassFromName(hash)
  if vehicleType == 'sea' then return class == 14 end
  if vehicleType == 'air' then return class == 15 or class == 16 end
  return class ~= 14 and class ~= 15 and class ~= 16
end

local function fetchList(garageName, pointIndex)
  local rows = lib.callback.await('hpx:garages:list', false, garageName, pointIndex)
  if type(rows) ~= 'table' then return nil end

  local vehicleType = Garages[garageName].vehicleType
  local list = {}
  for i = 1, #rows do
    local row = rows[i]
    local hash = resolveHash(row.model)
    local valid = IsModelInCdimage(hash) and IsModelAVehicle(hash)
    if not valid or matchesType(hash, vehicleType) then
      local label = valid and GetLabelText(GetDisplayNameFromVehicleModel(hash)) or row.model
      if label == 'NULL' then label = row.model end
      list[#list + 1] = {
        id = row.id,
        plate = row.plate,
        name = label,
        engine = row.engine,
        body = row.body,
        fuel = row.fuel,
        price = row.price,
        impounded = row.impounded,
        mine = row.mine,
        available = valid,
      }
    end
  end
  return list
end

local function closeGarage()
  if not isOpen then return end
  isOpen, current = false, nil
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

local function refresh()
  if not isOpen or not current then return end
  SendNUIMessage({ action = 'update', vehicles = fetchList(current.garage, current.point) or {} })
end

local function openGarage(garageName, pointIndex)
  if isOpen or isBusy or not Garages[garageName] then return end
  isBusy = true
  local list = fetchList(garageName, pointIndex)
  isBusy = false
  if not list then return notify(MESSAGES.denied, 'error') end

  isOpen, current = true, { garage = garageName, point = pointIndex }
  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    title = Garages[garageName].label,
    depot = Garages[garageName].type == 'depot',
    vehicles = list,
  })
end

local function spawnVehicle(vehicle, spawn, vehicleType)
  local hash = resolveHash(vehicle.model)
  if not pcall(lib.requestModel, hash, 10000) then return notify(MESSAGES.spawn_failed, 'error') end

  local entity = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
  SetModelAsNoLongerNeeded(hash)
  if entity == 0 then return notify(MESSAGES.spawn_failed, 'error') end

  SetEntityAsMissionEntity(entity, true, true)
  if vehicleType == 'car' then SetVehicleOnGroundProperly(entity) end
  lib.setVehicleProperties(entity, vehicle.props)
  SetVehicleNumberPlateText(entity, vehicle.plate)
  TaskWarpPedIntoVehicle(cache.ped, entity, -1)
end

local function retrieve(id)
  id = math.tointeger(tonumber(id))
  if not id or not isOpen or isBusy or not current then return end
  isBusy = true

  local garageName, pointIndex = current.garage, current.point
  local garage = Garages[garageName]
  local point = garage.accessPoints[pointIndex]
  local spawn = point.spawn or point.coords

  if lib.getClosestVehicle(spawn.xyz, Config.spawnClearRadius, false) then
    notify(MESSAGES.no_space, 'error')
    isBusy = false
    return
  end

  local res = lib.callback.await('hpx:garages:retrieve', false, id, garageName, pointIndex)
  if type(res) ~= 'table' or not res.ok then
    notify(MESSAGES[type(res) == 'table' and res.error or 'generic'] or MESSAGES.generic, 'error')
    refresh()
    isBusy = false
    return
  end

  closeGarage()
  spawnVehicle(res.vehicle, spawn, garage.vehicleType)
  isBusy = false
end

local function park(garageName, pointIndex)
  if isBusy then return end
  local ped = cache.ped
  local garage = Garages[garageName]
  local vehicle = GetVehiclePedIsIn(ped, false)

  if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return notify(MESSAGES.not_vehicle, 'error') end
  if not matchesType(GetEntityModel(vehicle), garage.vehicleType) then return notify(MESSAGES.wrong_type, 'error') end
  if GetEntitySpeed(vehicle) > 3.0 then return notify(MESSAGES.stop, 'error') end
  if not NetworkGetEntityIsNetworked(vehicle) then return notify(MESSAGES.invalid, 'error') end

  isBusy = true
  local props = lib.getVehicleProperties(vehicle)
  local netId = NetworkGetNetworkIdFromEntity(vehicle)

  TaskLeaveVehicle(ped, vehicle, 0)
  local deadline = GetGameTimer() + 4000
  while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(50) end

  local res = lib.callback.await('hpx:garages:park', false, netId, props, garageName, pointIndex)
  if type(res) == 'table' and res.ok then
    notify(MESSAGES.stored, 'success')
  else
    notify(MESSAGES[type(res) == 'table' and res.error or 'generic'] or MESSAGES.generic, 'error')
  end
  isBusy = false
end

local function createBlip(garage, point)
  if not point.blip then return end
  local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
  SetBlipSprite(blip, point.blip.sprite or 357)
  SetBlipColour(blip, point.blip.color or 3)
  SetBlipDisplay(blip, 4)
  SetBlipScale(blip, 0.7)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentSubstringPlayerName(point.blip.name or garage.label)
  EndTextCommandSetBlipName(blip)
  blips[#blips + 1] = blip
end

for garageName, garage in pairs(Garages) do
  for index, point in ipairs(garage.accessPoints) do
    createBlip(garage, point)

    lib.points.new({
      coords = point.coords.xyz,
      distance = point.radius or Config.interactDistance,
      onExit = function() setHint(nil) end,
      nearby = function()
        if isOpen or isBusy then return end

        local text
        if cache.vehicle then
          if cache.seat == -1 and garage.type ~= 'depot' then text = TEXT.park end
        else
          text = garage.type == 'depot' and TEXT.depot or TEXT.garage
        end
        setHint(text)

        if text and IsControlJustReleased(0, Config.control) then
          CreateThread(function()
            if cache.vehicle then park(garageName, index) else openGarage(garageName, index) end
          end)
        end
      end,
    })
  end
end

RegisterNUICallback('close', function(_, cb)
  closeGarage()
  cb('ok')
end)

RegisterNUICallback('retrieve', function(data, cb)
  cb('ok')
  if type(data) == 'table' then retrieve(data.id) end
end)

exports('Open', function(garageName, pointIndex)
  openGarage(garageName, math.tointeger(pointIndex) or 1)
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for i = 1, #blips do RemoveBlip(blips[i]) end
  if hint then lib.hideTextUI() end
  if isOpen then SetNuiFocus(false, false) end
end)

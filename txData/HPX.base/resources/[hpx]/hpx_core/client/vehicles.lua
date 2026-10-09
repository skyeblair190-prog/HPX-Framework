local function validVehicle(vehicle)
  return type(vehicle) == 'number' and vehicle ~= 0 and DoesEntityExist(vehicle)
end

exports('GetVehicleProperties', function(vehicle)
  if not validVehicle(vehicle) then return nil end
  return lib.getVehicleProperties(vehicle)
end)

exports('SetVehicleProperties', function(vehicle, props)
  if not validVehicle(vehicle) or type(props) ~= 'table' then return false end
  lib.setVehicleProperties(vehicle, props)
  return true
end)

exports('SetVehicleStored', function(vehicle, stored)
  if not validVehicle(vehicle) then return false end
  SetVehicleDoorsLocked(vehicle, stored and 2 or 1)
  return true
end)

local SUBMARINES <const> = {
  [joaat('submersible')] = true,
  [joaat('submersible2')] = true,
  [joaat('kosatka')] = true,
}

lib.callback.register('hpx:vehicles:getVehicleType', function(model)
  if type(model) ~= 'number' or not IsModelInCdimage(model) or not IsModelAVehicle(model) then return nil end
  if SUBMARINES[model] then return 'submarine' end
  if IsThisModelABike(model) or IsThisModelABicycle(model) then return 'bike' end
  if IsThisModelAHeli(model) then return 'heli' end
  if IsThisModelAPlane(model) then return 'plane' end
  if IsThisModelABoat(model) or IsThisModelAJetski(model) then return 'boat' end
  return 'automobile'
end)

AddStateBagChangeHandler('setVehicleProperties', nil, function(bagName, _, value)
  if not value then return end

  local netId = tonumber((bagName:gsub('entity:', '')))
  if not netId then return end

  local ok, entity = pcall(lib.waitFor, function()
    if NetworkDoesEntityExistWithNetworkId(netId) then return NetToVeh(netId) end
  end, 'vehicle did not stream in', 10000)
  if not ok or not entity or entity == 0 then return end

  if NetworkGetEntityOwner(entity) ~= cache.playerId then return end

  lib.setVehicleProperties(entity, value)
  Entity(entity).state:set('setVehicleProperties', nil, true)
end)

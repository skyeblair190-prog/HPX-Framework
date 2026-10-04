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

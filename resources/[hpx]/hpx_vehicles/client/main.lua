exports('GetVehicleProperties', function(vehicle)
  if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
  return {
    plate = GetVehicleNumberPlateText(vehicle),
    model = GetEntityModel(vehicle),
    fuel = GetVehicleFuelLevel(vehicle),
    body = GetVehicleBodyHealth(vehicle),
    engine = GetVehicleEngineHealth(vehicle)
  }
end)

exports('SetVehicleStored', function(vehicle, stored)
  if vehicle == 0 then return false end
  SetVehicleDoorsLocked(vehicle, stored and 2 or 1)
  return true
end)

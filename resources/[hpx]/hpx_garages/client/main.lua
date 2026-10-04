exports('Open', function(garage)
  local vehicles = lib.callback.await('hpx:garages:list', false, garage)
  TriggerEvent('hpx:garages:opened', garage, vehicles)
  return vehicles
end)

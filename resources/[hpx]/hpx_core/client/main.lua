local playerData, loaded = {}, false

RegisterNetEvent('hpx:client:characterLoaded', function(data)
  playerData = type(data) == 'table' and data or {}
  loaded = true
end)

RegisterNetEvent('hpx:client:setPlayerData', function(data)
  if type(data) == 'table' then playerData = data end
end)

RegisterNetEvent('hpx:client:characterUnloaded', function()
  playerData, loaded = {}, false
end)

exports('GetPlayerData', function()
  return playerData
end)

exports('IsLoaded', function()
  return loaded
end)

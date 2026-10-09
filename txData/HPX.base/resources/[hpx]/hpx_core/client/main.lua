local playerData, loaded = {}, false

local function updateIdentity()
  if not loaded then
    LocalPlayer.state:set('hpx:identity', nil, false)
    return
  end

  local charinfo = playerData.charinfo or {}
  local name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
  name = name:gsub('^%s+', ''):gsub('%s+$', '')

  LocalPlayer.state:set('hpx:identity', {
    citizenid = playerData.citizenid,
    name = name,
    phone = playerData.phone,
    job = playerData.job,
    gang = playerData.gang
  }, false)
end

RegisterNetEvent('hpx:client:characterLoaded', function(data)
  playerData = type(data) == 'table' and data or {}
  loaded = true
  updateIdentity()
end)

RegisterNetEvent('hpx:client:setPlayerData', function(data)
  if type(data) == 'table' then
    playerData = data
    updateIdentity()
  end
end)

RegisterNetEvent('hpx:client:characterUnloaded', function()
  playerData, loaded = {}, false
  updateIdentity()
end)

exports('GetPlayerData', function()
  return playerData
end)

exports('IsLoaded', function()
  return loaded
end)

exports('GetIdentity', function()
  return LocalPlayer.state['hpx:identity']
end)

local lastSave = {}

RegisterNetEvent('hpx:core:requestSave', function()
  local source = source
  local now = GetGameTimer()
  if lastSave[source] and now - lastSave[source] < 30000 then return end
  lastSave[source] = now
  HPXServer.Character.Save(source)
end)

AddEventHandler('playerDropped', function()
  local source = source
  local player = HPXServer.GetPlayer(source)
  if player and HPXConfig.persistence.saveOnDrop then
    HPXServer.Character.Save(source)
  end
  if player then TriggerEvent('hpx:server:characterUnloaded', source, player) end
  HPXServer.RemovePlayer(source)
  lastSave[source] = nil
end)

CreateThread(function()
  while true do
    Wait(HPXConfig.persistence.saveInterval)
    for source in pairs(HPXServer.Players) do
      if HPXValidate.source(source) then
        HPXServer.Character.Save(source)
      end
    end
  end
end)

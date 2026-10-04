RegisterNetEvent('hpx:core:requestSave', function()
  local source = source
  HPXServer.Character.Save(source)
end)

AddEventHandler('playerDropped', function()
  local source = source
  local player = HPXServer.GetPlayer(source)
  if player and HPXConfig.persistence.saveOnDrop then
    HPXServer.Character.Save(source)
  end
  HPXServer.RemovePlayer(source)
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

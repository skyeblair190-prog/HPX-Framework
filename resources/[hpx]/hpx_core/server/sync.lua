function HPXServer.GetClientData(player)
  return {
    citizenid = player.citizenid,
    charinfo = player.charinfo,
    money = player.money,
    job = player.job,
    gang = player.gang,
    metadata = player.metadata,
    phone = player.phone,
    position = player.position,
    permission = player.permission
  }
end

function HPXServer.SyncClient(source)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end
  TriggerClientEvent('hpx:client:setPlayerData', source, HPXServer.GetClientData(player))
  return true
end

local function sync(source)
  local player = exports.hpx_core:GetPlayer(source)
  if not player then return end
  TriggerClientEvent('hpx:identity:sync', source, {
    citizenid = player.citizenid,
    name = player:GetName(),
    phone = player.phone,
    job = player.job,
    gang = player.gang
  })
end

AddEventHandler('hpx:server:characterLoaded', function(source)
  sync(source)
end)

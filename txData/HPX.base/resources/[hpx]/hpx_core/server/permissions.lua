function HPXServer.GetPermissionLevel(source)
  local player = HPXServer.GetPlayer(source)
  return player and player.permission or 0
end

function HPXServer.HasPermission(source, level)
  local required = type(level) == 'number' and level or (HPXConstants.permissions[level] or 0)
  return HPXServer.GetPermissionLevel(source) >= required
end

function HPXServer.SetPermission(source, level)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end
  player.permission = type(level) == 'number' and level or (HPXConstants.permissions[level] or 0)
  return true
end

exports('SetPermission', function(source, level)
  return HPXServer.SetPermission(source, level)
end)

exports('SetJobDuty', function(source, onDuty)
  local player = HPXServer.GetPlayer(source)
  if not player or type(player.job) ~= 'table' then return false end
  player.job.onduty = onDuty == true
  HPXServer.SyncClient(source)
  return player.job.onduty
end)

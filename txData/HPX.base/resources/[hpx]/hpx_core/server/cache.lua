HPXServer = HPXServer or {}
HPXServer.Players = HPXServer.Players or {}
HPXServer.Licenses = HPXServer.Licenses or {}

function HPXServer.GetPlayer(source)
  return HPXServer.Players[source]
end

function HPXServer.SetPlayer(source, player)
  HPXServer.Players[source] = player
  if player and player.license then HPXServer.Licenses[player.license] = source end
end

function HPXServer.RemovePlayer(source)
  local player = HPXServer.Players[source]
  if player and player.license then HPXServer.Licenses[player.license] = nil end
  HPXServer.Players[source] = nil
  return player
end

function HPXServer.GetSourceByLicense(license)
  return license and HPXServer.Licenses[license] or nil
end

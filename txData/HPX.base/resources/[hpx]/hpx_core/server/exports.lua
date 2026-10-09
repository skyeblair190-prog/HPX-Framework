exports('GetPlayer', function(source)
  return HPXServer.GetPlayer(source)
end)

exports('GetPlayers', function()
  return HPXServer.Players
end)

exports('GetSourceByLicense', function(license)
  return HPXServer.GetSourceByLicense(license)
end)

exports('GetMoney', function(source, kind)
  return HPXServer.Money.Get(source, kind)
end)

exports('AddMoney', function(source, kind, amount, reason)
  return HPXServer.Money.Change(source, kind, math.abs(tonumber(amount) or 0), reason)
end)

exports('RemoveMoney', function(source, kind, amount, reason)
  return HPXServer.Money.Change(source, kind, -math.abs(tonumber(amount) or 0), reason)
end)

exports('HasPermission', function(source, level)
  return HPXServer.HasPermission(source, level)
end)

exports('SavePlayer', function(source)
  return HPXServer.Character.Save(source)
end)

exports('LoadCharacter', function(source, id)
  return HPXServer.Character.Load(source, id)
end)

exports('CreateCharacter', function(source, slot, charinfo)
  return HPXServer.Character.Create(source, slot, charinfo)
end)

exports('GetCharacters', function(source)
  return HPXServer.Character.List(source)
end)

exports('DeleteCharacter', function(source, id)
  return HPXServer.Character.Delete(source, id)
end)

exports('GenerateAccountNumber', function()
  return HPXServer.GenerateAccountNumber()
end)

exports('GenerateCitizenId', function()
  return HPXServer.GenerateCitizenId()
end)

exports('GeneratePhoneNumber', function()
  return HPXServer.GeneratePhoneNumber()
end)

exports('SetMoney', function(source, kind, amount, reason)
  return HPXServer.Money.Set(source, kind, amount, reason)
end)

exports('UnloadCharacter', function(source)
  return HPXServer.Character.Unload(source)
end)

exports('CreateUsableItem', function(name, cb)
  return HPXServer.CreateUsableItem(name, cb)
end)

exports('CanUseItem', function(name)
  return HPXServer.CanUseItem(name)
end)

exports('IsGradeBoss', function(group, grade)
  return HPXServer.IsGradeBoss(group, grade)
end)

exports('GetPlayersData', function()
  local list = {}
  for source, player in pairs(HPXServer.Players) do
    local data = HPXServer.GetClientData(player)
    data.source = source
    list[#list + 1] = data
  end
  return list
end)

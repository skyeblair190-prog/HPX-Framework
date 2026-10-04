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

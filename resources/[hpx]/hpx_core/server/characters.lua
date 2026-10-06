lib.callback.register('hpx:characters:list', function(source)
  return HPXServer.Character.List(source)
end)

lib.callback.register('hpx:characters:create', function(source, data)
  if type(data) ~= 'table' then return nil, 'invalid_data' end
  local player, err = HPXServer.Character.Create(source, data.slot, data.charinfo)
  if not player then return nil, err end
  return HPXServer.GetClientData(player)
end)

lib.callback.register('hpx:characters:select', function(source, id)
  local player, err = HPXServer.Character.Load(source, id)
  if not player then return nil, err end
  return HPXServer.GetClientData(player)
end)

lib.callback.register('hpx:characters:delete', function(source, id)
  return HPXServer.Character.Delete(source, id)
end)

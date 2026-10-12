lib.callback.register('hpx:characters:list', function(source)
  local list, err = HPXServer.Character.List(source)
  if not list then return nil, err end
  return list, HPXServer.Character.MaxSlots(source), HPXServer.Character.Skins(list)
end)

lib.callback.register('hpx:characters:enter', function(source)
  if HPXServer.GetPlayer(source) then return false end
  SetPlayerRoutingBucket(source, 5000 + source)
  return true
end)

lib.callback.register('hpx:characters:logout', function(source)
  return HPXServer.Character.Unload(source)
end)

lib.callback.register('hpx:characters:create', function(source, data)
  if type(data) ~= 'table' then return nil, 'invalid_data' end
  local player, err = HPXServer.Character.Create(source, data.slot, data.charinfo)
  if not player then return nil, err end
  return HPXServer.GetClientData(player)
end)

lib.callback.register('hpx:characters:select', function(source, data)
  local id, spawn = data, nil
  if type(data) == 'table' then id, spawn = data.id, data.spawn end
  local player, err = HPXServer.Character.Load(source, id, false, spawn)
  if not player then return nil, err end
  return HPXServer.GetClientData(player)
end)

lib.callback.register('hpx:characters:delete', function(source, data)
  if type(data) == 'table' then
    return HPXServer.Character.Delete(source, data.id, tostring(data.confirm or ''))
  end
  return HPXServer.Character.Delete(source, data)
end)

lib.callback.register('hpx:characters:autoload', function(source)
  if not HPXConfig.character.autoLoad then return nil, 'disabled' end
  if HPXServer.GetPlayer(source) then return nil, 'already_loaded' end

  local list, err = HPXServer.Character.List(source)
  if not list then return nil, err end

  local player, loadErr
  if #list == 0 then
    player, loadErr = HPXServer.Character.Create(source, 1, {})
  else
    player, loadErr = HPXServer.Character.Load(source, list[1].id)
  end

  if not player then return nil, loadErr end
  return true
end)

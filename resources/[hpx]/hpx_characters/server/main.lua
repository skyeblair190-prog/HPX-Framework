local function snapshot(player)
  return {
    citizenid = player.citizenid,
    charinfo = player.charinfo,
    money = player.money,
    job = player.job,
    gang = player.gang,
    metadata = player.metadata,
    position = player.position,
    phone = player.phone
  }
end

lib.callback.register('hpx:characters:list', function(source)
  return exports.hpx_core:GetCharacters(source)
end)

lib.callback.register('hpx:characters:create', function(source, data)
  if type(data) ~= 'table' then return nil, 'invalid_data' end
  local player, err = exports.hpx_core:CreateCharacter(source, data.slot, data.charinfo)
  if not player then return nil, err end
  return snapshot(player)
end)

lib.callback.register('hpx:characters:select', function(source, id)
  local player, err = exports.hpx_core:LoadCharacter(source, id)
  if not player then return nil, err end
  return snapshot(player)
end)

lib.callback.register('hpx:characters:delete', function(source, id)
  return exports.hpx_core:DeleteCharacter(source, id)
end)

local function request(action, data)
  return lib.callback.await('hpx:characters:' .. action, false, data)
end

RegisterNetEvent('hpx:client:characterCount', function(count)
  TriggerEvent('hpx:characters:countChanged', count)
end)

RegisterCommand('characters', function()
  local characters = request('list')
  if not characters then return end
  TriggerEvent('hpx:characters:opened', characters)
end, false)

exports('GetCharacters', function()
  return request('list')
end)

exports('SelectCharacter', function(id)
  return request('select', tonumber(id))
end)

exports('CreateCharacter', function(slot, charinfo)
  return request('create', { slot = slot, charinfo = charinfo })
end)

exports('DeleteCharacter', function(id)
  return request('delete', tonumber(id))
end)

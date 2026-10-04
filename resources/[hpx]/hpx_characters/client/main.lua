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

exports('List', function()
  return request('list')
end)

exports('Select', function(id)
  return request('select', tonumber(id))
end)

exports('Create', function(slot, charinfo)
  return request('create', { slot = slot, charinfo = charinfo })
end)

exports('Delete', function(id)
  return request('delete', tonumber(id))
end)

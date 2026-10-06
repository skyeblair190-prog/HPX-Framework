local registry, warned = {}, false

local function interactReady()
  return GetResourceState('interact') == 'started'
end

local function register(fn, data)
  if type(data) ~= 'table' then return false end

  registry[#registry + 1] = { fn = fn, data = data }

  if not interactReady() then
    if not warned then
      warned = true
      print('^3[hpx_core]^7 interactions are queued until the "interact" resource is started')
    end
    return true
  end

  return exports.interact[fn](exports.interact, data)
end

AddEventHandler('onClientResourceStart', function(resource)
  if resource ~= 'interact' then return end
  for i = 1, #registry do
    local entry = registry[i]
    pcall(function() exports.interact[entry.fn](exports.interact, entry.data) end)
  end
end)

exports('AddModelInteraction', function(data)
  return register('AddModelInteraction', data)
end)

exports('AddInteraction', function(data)
  return register('AddInteraction', data)
end)

exports('RemoveModelInteraction', function(name)
  for i = #registry, 1, -1 do
    local entry = registry[i]
    if entry.fn == 'AddModelInteraction' and entry.data.name == name then
      table.remove(registry, i)
    end
  end

  if not interactReady() then return false end
  local ok, result = pcall(function() return exports.interact:RemoveModelInteraction(name) end)
  return ok and result or false
end)

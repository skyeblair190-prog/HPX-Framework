local open = false

local function showPayPhone()
  if open then return end
  open = true
  SendNUIMessage({ action = 'showPayPhone', numberlimit = Config.limit })
  SetNuiFocus(true, true)
end

local function hidePayPhone()
  open = false
  SendNUIMessage({ action = 'hidePayPhone' })
  SetNuiFocus(false, false)
end

RegisterNetEvent('cd-payphone:showpphone', showPayPhone)

RegisterCommand('hidepayphone', hidePayPhone, false)

RegisterNUICallback('dialnumber', function(data, cb)
  hidePayPhone()

  local number = type(data) == 'table' and tostring(data.number or '') or ''
  if not number:match('^%d+$') or #number > Config.limit then
    exports.hpx_notify:Notify('Invalid phone number.', 'error')
    return cb('error')
  end

  if Config.PhoneResource and GetResourceState(Config.PhoneResource) == 'started' then
    exports[Config.PhoneResource]:CallContact({ number = number, name = number }, true)
  else
    exports.hpx_notify:Notify('Phone service is unavailable.', 'error')
  end

  cb('ok')
end)

RegisterNUICallback('escape', function(_, cb)
  hidePayPhone()
  cb('ok')
end)

CreateThread(function()
  local modelData = {}
  for _, model in ipairs(Config.Models) do
    modelData[#modelData + 1] = { model = model, offset = vec3(0.0, 0.0, 1.2) }
  end

  exports.interact:AddModelInteraction({
    name = 'hpx_payphone',
    modelData = modelData,
    distance = 5.0,
    interactDst = 1.5,
    options = {
      { name = 'hpx_payphone:use', label = 'Use Payphone', action = showPayPhone }
    }
  })
end)

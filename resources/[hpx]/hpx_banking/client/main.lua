local open = false

local function close()
  if not open then return end
  open = false
  SendNUIMessage({ action = 'hpx:bank:close' })
  SetNuiFocus(false, false)
end

local function openBank()
  if open then return end
  local account = lib.callback.await('hpx:banking:getAccount', false)
  if not account then return end
  open = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'hpx:bank:open', account = account })
end

RegisterNUICallback('close', function(_, cb) close(); cb(true) end)
RegisterNUICallback('deposit', function(data, cb)
  cb({ ok = lib.callback.await('hpx:banking:deposit', false, data.amount, data.description) })
end)
RegisterNUICallback('withdraw', function(data, cb)
  cb({ ok = lib.callback.await('hpx:banking:withdraw', false, data.amount, data.description) })
end)
RegisterNUICallback('transfer', function(data, cb)
  cb({ ok = lib.callback.await('hpx:banking:transfer', false, data) })
end)

RegisterCommand('hpxbank', openBank, false)
exports('Open', openBank)
exports('Close', close)

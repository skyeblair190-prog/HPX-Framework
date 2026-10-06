HPXBank = {}

local config = HPXBankingConfig
local MENU <const> = { 'balance', 'withdraw', 'deposit', 'transfer', 'exit' }

local S = { active = false }

local function cash()
  local data = exports.hpx_core:GetPlayerData()
  return data and data.money and tonumber(data.money.cash) or 0
end

local function items()
  local list = {}

  if S.screen == 'menu' then
    for i, id in ipairs(MENU) do list[i] = { id = id } end
  elseif S.screen == 'amounts' then
    for i, value in ipairs(config.atm.quickAmounts) do list[i] = { id = 'amount', value = value } end
    list[#list + 1] = { id = 'custom' }
    list[#list + 1] = { id = 'back' }
  end

  return list
end

local function view()
  return {
    screen = S.screen,
    kind = S.kind,
    index = S.index,
    items = items(),
    account = S.account and { number = S.account.number, balance = S.account.balance } or nil,
    cash = cash(),
    currency = config.currency,
    busy = S.busy == true,
    result = S.result
  }
end

local function render()
  if not S.active then return end

  local payload = { action = 'view', view = view() }
  if S.mode == 'dui' then
    HPXBank.SendDui(payload)
  else
    SendNUIMessage(payload)
  end
end

local function toMenu()
  S.screen, S.kind, S.result, S.index = 'menu', nil, nil, 1
  render()
end

local function showResult(kind, key, amount)
  S.screen, S.result, S.index = 'result', { kind = kind, key = key, amount = amount }, 1
  render()

  local token = (S.token or 0) + 1
  S.token = token
  SetTimeout(3500, function()
    if S.active and S.screen == 'result' and S.token == token then toMenu() end
  end)
end

local function refreshAccount()
  S.account = lib.callback.await('hpx:banking:getAccount', false) or S.account
end

local function restoreFocus()
  if S.active and S.mode == 'nui' then SetNuiFocus(true, true) end
end

local function perform(kind, amount)
  amount = tonumber(amount)
  if not amount or amount <= 0 then return showResult('error', 'invalid') end

  S.lock, S.busy = true, true
  render()

  local description = kind == 'deposit' and 'ATM deposit' or 'ATM withdrawal'
  local ok, reason = lib.callback.await('hpx:banking:' .. kind, false, amount, description)

  S.lock, S.busy = false, false
  if not S.active then return end

  refreshAccount()
  if ok then
    showResult('success', kind .. '_ok', amount)
  else
    showResult('error', reason or 'error', amount)
  end
end

local function askAmount(title)
  S.lock = true
  local input = lib.inputDialog(title, {
    { type = 'number', label = 'Amount', min = 1, max = config.transactionLimit, required = true }
  })
  S.lock = false
  restoreFocus()
  return input and tonumber(input[1]) or nil
end

local function transfer()
  S.lock = true
  local input = lib.inputDialog('Transfer funds', {
    { type = 'input', label = 'Account number', required = true, min = 1, max = 32 },
    { type = 'number', label = 'Amount', min = 1, max = config.transactionLimit, required = true },
    { type = 'input', label = 'Reference', max = 64 }
  })
  S.lock = false
  restoreFocus()
  if not input or not S.active then return end

  local amount = tonumber(input[2])
  if not amount or amount <= 0 then return showResult('error', 'invalid') end

  S.lock, S.busy = true, true
  render()
  local ok, reason = lib.callback.await('hpx:banking:transfer', false, {
    accountNumber = tostring(input[1] or ''),
    amount = amount,
    description = tostring(input[3] or 'Transfer'):sub(1, 64)
  })
  S.lock, S.busy = false, false
  if not S.active then return end

  refreshAccount()
  if ok then
    showResult('success', 'transfer_ok', amount)
  else
    showResult('error', reason or 'error', amount)
  end
end

function HPXBank.IsActive()
  return S.active
end

function HPXBank.GetMode()
  return S.mode
end

function HPXBank.Move(step)
  if not S.active or S.lock then return end
  local count = #items()
  if count == 0 then return end
  S.index = ((S.index - 1 + step) % count) + 1
  render()
end

function HPXBank.Select(index)
  if not S.active or S.lock then return end

  if S.screen == 'result' then return toMenu() end

  local list = items()
  index = index or S.index
  local item = list[index]
  if not item then return end
  S.index = index

  if S.screen == 'menu' then
    if item.id == 'balance' then
      refreshAccount()
      return showResult('success', 'balance')
    elseif item.id == 'withdraw' or item.id == 'deposit' then
      S.screen, S.kind, S.index = 'amounts', item.id, 1
      return render()
    elseif item.id == 'transfer' then
      return transfer()
    end
    return HPXBank.Close()
  end

  if item.id == 'amount' then
    return perform(S.kind, item.value)
  elseif item.id == 'custom' then
    local value = askAmount(S.kind == 'deposit' and 'Deposit cash' or 'Withdraw cash')
    if value then perform(S.kind, value) end
    return
  end

  toMenu()
end

function HPXBank.Back()
  if not S.active or S.lock then return end
  if S.screen == 'menu' then return HPXBank.Close() end
  toMenu()
end

function HPXBank.Start(mode, entity, model)
  if S.active or not exports.hpx_core:IsLoaded() then return false end

  local account = lib.callback.await('hpx:banking:getAccount', false)
  if not account then return false end

  S = { active = true, mode = mode, screen = 'menu', index = 1, account = account }

  if mode == 'dui' then
    HPXBank.BeginDui(entity, model)
  else
    SetNuiFocus(true, true)
  end

  render()
  return true
end

function HPXBank.Close()
  if not S.active then return end

  local mode = S.mode
  S = { active = false }

  if mode == 'dui' then
    HPXBank.EndDui()
  else
    SendNUIMessage({ action = 'view', view = { screen = 'idle' } })
    SetNuiFocus(false, false)
  end
end

RegisterNUICallback('select', function(data, cb)
  cb(true)
  if S.mode ~= 'nui' or type(data) ~= 'table' then return end
  local index = math.tointeger(tonumber(data.index))
  if index then CreateThread(function() HPXBank.Select(index) end) end
end)

RegisterNUICallback('input', function(data, cb)
  cb(true)
  if S.mode ~= 'nui' or type(data) ~= 'table' then return end

  if data.key == 'up' then
    HPXBank.Move(-1)
  elseif data.key == 'down' then
    HPXBank.Move(1)
  elseif data.key == 'enter' then
    CreateThread(function() HPXBank.Select() end)
  elseif data.key == 'back' then
    CreateThread(HPXBank.Back)
  elseif data.key == 'close' then
    HPXBank.Close()
  end
end)

RegisterCommand('hpxbank', function() HPXBank.Start('nui') end, false)
exports('Open', function() return HPXBank.Start('nui') end)
exports('Close', HPXBank.Close)

AddEventHandler('onResourceStop', function(resource)
  if resource == GetCurrentResourceName() then HPXBank.Close() end
end)

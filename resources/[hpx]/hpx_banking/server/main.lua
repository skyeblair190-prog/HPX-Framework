local function player(source)
  return exports.hpx_core:GetPlayer(source)
end

local function amount(value)
  value = tonumber(value)
  if not value or value <= 0 or value > HPXBankingConfig.transactionLimit then return nil end
  return math.floor(value * 100) / 100
end

local function account(source, kind)
  local p = player(source)
  if not p then return nil end
  kind = kind or HPXBankingConfig.defaultAccountType

  local row = MySQL.single.await(
    'SELECT id, account_number, account_type, balance FROM hpx_accounts WHERE character_id = ? AND account_type = ? LIMIT 1',
    { p.charid, kind }
  )
  if row then return row end

  local number = exports.hpx_core:GenerateAccountNumber()
  local id = MySQL.insert.await(
    'INSERT INTO hpx_accounts (character_id, account_number, account_type, balance) VALUES (?, ?, ?, 0)',
    { p.charid, number, kind }
  )
  if not id then return nil end
  return { id = id, account_number = number, account_type = kind, balance = 0 }
end

local function logTx(row, p, kind, value, description, reference)
  return MySQL.insert.await([[
    INSERT INTO hpx_bank_transactions
      (account_id, character_id, type, amount, balance_after, description, reference)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  ]], { row.id, p.charid, kind, value, row.balance, description, reference })
end

lib.callback.register('hpx:banking:getAccount', function(source, kind)
  local row = account(source, kind)
  if not row then return nil end
  return { id = row.id, number = row.account_number, type = row.account_type, balance = tonumber(row.balance) or 0 }
end)

lib.callback.register('hpx:banking:transactions', function(source, limit)
  local row = account(source)
  if not row then return {} end
  limit = math.max(1, math.min(50, tonumber(limit) or 25))
  return MySQL.query.await(
    ('SELECT id, type, amount, balance_after, description, reference, created_at FROM hpx_bank_transactions WHERE account_id = ? ORDER BY id DESC LIMIT %d'):format(limit),
    { row.id }
  )
end)

lib.callback.register('hpx:banking:deposit', function(source, raw, description)
  local value = amount(raw)
  local p, row = player(source), account(source)
  if not value or not p or not row then return false, 'invalid' end
  if not p:RemoveMoney('cash', value, 'bank-deposit') then return false, 'insufficient_cash' end

  local changed = MySQL.update.await('UPDATE hpx_accounts SET balance = balance + ? WHERE id = ?', { value, row.id })
  if changed ~= 1 then
    p:AddMoney('cash', value, 'bank-deposit-reversal')
    return false, 'database_error'
  end

  row.balance = tonumber(row.balance) + value
  logTx(row, p, 'deposit', value, description or 'Cash deposit')
  return true
end)

lib.callback.register('hpx:banking:withdraw', function(source, raw, description)
  local value = amount(raw)
  local p, row = player(source), account(source)
  if not value or not p or not row then return false, 'invalid' end

  local changed = MySQL.update.await(
    'UPDATE hpx_accounts SET balance = balance - ? WHERE id = ? AND balance >= ?',
    { value, row.id, value }
  )
  if changed ~= 1 then return false, 'insufficient_funds' end

  if not p:AddMoney('cash', value, 'bank-withdraw') then
    MySQL.update.await('UPDATE hpx_accounts SET balance = balance + ? WHERE id = ?', { value, row.id })
    return false, 'cash_error'
  end

  row.balance = tonumber(row.balance) - value
  logTx(row, p, 'withdraw', value, description or 'Cash withdrawal')
  return true
end)

lib.callback.register('hpx:banking:transfer', function(source, data)
  if type(data) ~= 'table' then return false, 'invalid' end
  local value = amount(data.amount)
  local p, from = player(source), account(source)
  local number = tostring(data.accountNumber or '')
  if not value or not p or not from or number == '' or number == from.account_number then return false, 'invalid' end

  local to = MySQL.single.await(
    'SELECT id, character_id, account_number, balance FROM hpx_accounts WHERE account_number = ? LIMIT 1',
    { number }
  )
  if not to then return false, 'account_not_found' end

  local ok = MySQL.transaction.await({
    { 'UPDATE hpx_accounts SET balance = balance - ? WHERE id = ? AND balance >= ?', { value, from.id, value } },
    { 'UPDATE hpx_accounts SET balance = balance + ? WHERE id = ?', { value, to.id } }
  })
  if not ok then return false, 'transfer_failed' end

  from.balance = tonumber(from.balance) - value
  to.balance = tonumber(to.balance) + value
  logTx(from, p, 'transfer_out', value, data.description or 'Transfer', number)
  MySQL.insert.await([[
    INSERT INTO hpx_bank_transactions
      (account_id, character_id, type, amount, balance_after, description, reference)
    VALUES (?, ?, 'transfer_in', ?, ?, ?, ?)
  ]], { to.id, to.character_id, value, to.balance, data.description or 'Transfer', from.account_number })

  return true
end)

exports('GetAccount', account)
exports('GetBalance', function(source, kind)
  local row = account(source, kind)
  return row and tonumber(row.balance) or nil
end)

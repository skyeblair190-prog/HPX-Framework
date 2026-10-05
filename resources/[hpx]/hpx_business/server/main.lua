local function player(source) return exports.hpx_core:GetPlayer(source) end

CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_businesses (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(64) NOT NULL,
      label VARCHAR(128) NOT NULL,
      owner_character_id BIGINT UNSIGNED NULL,
      funds DECIMAL(15,2) NOT NULL DEFAULT 0,
      data LONGTEXT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_hpx_business_name (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
end)

lib.callback.register('hpx:business:get', function(source, name)
  local p = player(source)
  if not p or type(name) ~= 'string' then return nil end
  return MySQL.single.await(
    'SELECT id, name, label, owner_character_id, funds, data FROM hpx_businesses WHERE name = ? LIMIT 1',
    { name }
  )
end)

lib.callback.register('hpx:business:deposit', function(source, name, amount)
  local p = player(source)
  amount = tonumber(amount)
  if not p or type(name) ~= 'string' or not amount then return false end

  amount = math.floor(amount * 100 + 0.5) / 100
  if amount <= 0 then return false end

  local business = MySQL.single.await('SELECT id FROM hpx_businesses WHERE name = ? LIMIT 1', { name })
  if not business or not p:RemoveMoney('bank', amount, 'business-deposit') then return false end

  if MySQL.update.await('UPDATE hpx_businesses SET funds = funds + ? WHERE id = ?', { amount, business.id }) ~= 1 then
    p:AddMoney('bank', amount, 'business-deposit-refund')
    return false
  end

  return true
end)

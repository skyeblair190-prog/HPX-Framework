CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_characters (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      license VARCHAR(96) NOT NULL,
      citizenid VARCHAR(32) NOT NULL,
      slot TINYINT UNSIGNED NOT NULL,
      charinfo LONGTEXT NOT NULL,
      money LONGTEXT NOT NULL,
      job LONGTEXT NOT NULL,
      gang LONGTEXT NOT NULL,
      metadata LONGTEXT NOT NULL,
      position LONGTEXT NULL,
      permission SMALLINT NOT NULL DEFAULT 0,
      phone VARCHAR(32) NULL,
      last_seen TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_hpx_citizenid (citizenid),
      UNIQUE KEY uq_hpx_license_slot (license, slot),
      KEY idx_hpx_license (license)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_accounts (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      character_id BIGINT UNSIGNED NOT NULL,
      account_number VARCHAR(32) NOT NULL,
      account_type VARCHAR(32) NOT NULL DEFAULT 'checking',
      balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_hpx_account_number (account_number),
      UNIQUE KEY uq_hpx_character_type (character_id, account_type),
      KEY idx_hpx_account_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_bank_transactions (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      account_id BIGINT UNSIGNED NOT NULL,
      character_id BIGINT UNSIGNED NOT NULL,
      type VARCHAR(32) NOT NULL,
      amount DECIMAL(18,2) NOT NULL,
      balance_after DECIMAL(18,2) NOT NULL,
      description VARCHAR(255) NULL,
      reference VARCHAR(64) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_hpx_tx_account (account_id, created_at),
      KEY idx_hpx_tx_character (character_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  TriggerEvent('hpx:server:ready')
end)

AddEventHandler('playerJoining', function()
  local source = source
  local license = HPXGetLicense(source)
  if not license then return end

  local count = MySQL.scalar.await('SELECT COUNT(*) FROM hpx_characters WHERE license = ?', { license })
  TriggerClientEvent('hpx:client:characterCount', source, tonumber(count) or 0)
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() or not HPXConfig.persistence.saveOnResourceStop then return end
  for source in pairs(HPXServer.Players) do
    HPXServer.Character.Save(source)
  end
end)

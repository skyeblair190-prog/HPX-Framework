local MAX_DATA_SIZE <const> = 8192

local function player(source) return exports.hpx_core:GetPlayer(source) end

CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_evidence (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      character_id BIGINT UNSIGNED NOT NULL,
      type VARCHAR(64) NOT NULL,
      label VARCHAR(128) NOT NULL,
      data LONGTEXT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_hpx_evidence_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
end)

lib.callback.register('hpx:evidence:create', function(source, data)
  local p = player(source)
  if not p or type(data) ~= 'table' then return nil end

  local encoded = json.encode(data)
  if not encoded or #encoded > MAX_DATA_SIZE then return nil end

  return MySQL.insert.await(
    'INSERT INTO hpx_evidence (character_id, type, label, data) VALUES (?, ?, ?, ?)',
    { p.charid, tostring(data.type or 'unknown'):sub(1, 64), tostring(data.label or 'Evidence'):sub(1, 128), encoded }
  )
end)

lib.callback.register('hpx:evidence:list', function(source)
  local p = player(source)
  if not p then return {} end
  return MySQL.query.await(
    'SELECT id, type, label, data, created_at FROM hpx_evidence WHERE character_id = ? ORDER BY id DESC LIMIT 100',
    { p.charid }
  )
end)

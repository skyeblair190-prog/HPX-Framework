local PLATE_CHARS <const> = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
local PLATE_LENGTH <const> = 8
local DEFAULT_GARAGE <const> = 'pillbox'

local function normalizePlate(plate)
  return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

local function validPlate(plate)
  return #plate >= 1 and #plate <= PLATE_LENGTH and plate:find('^[%w ]+$') ~= nil
end

local function decodeProps(raw)
  if type(raw) ~= 'string' or raw == '' then return {} end
  local ok, decoded = pcall(json.decode, raw)
  return ok and type(decoded) == 'table' and decoded or {}
end

local function ensureColumn(name, definition)
  local exists = MySQL.scalar.await(
    'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
    { 'hpx_vehicles', name }
  )
  if (tonumber(exists) or 0) == 0 then
    MySQL.query.await(('ALTER TABLE hpx_vehicles ADD COLUMN %s %s'):format(name, definition))
  end
end

CreateThread(function()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS hpx_vehicles (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      character_id BIGINT UNSIGNED NOT NULL,
      plate VARCHAR(8) NOT NULL,
      model VARCHAR(64) NOT NULL,
      props LONGTEXT NULL,
      stored TINYINT(1) NOT NULL DEFAULT 1,
      garage VARCHAR(64) NOT NULL DEFAULT 'pillbox',
      state VARCHAR(16) NOT NULL DEFAULT 'normal',
      depot_price INT UNSIGNED NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_hpx_vehicle_plate (plate),
      KEY idx_hpx_vehicle_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])
  ensureColumn('depot_price', 'INT UNSIGNED NOT NULL DEFAULT 0')
end)

local function generatePlate()
  for _ = 1, 25 do
    local chars = {}
    for i = 1, PLATE_LENGTH do
      local n = math.random(#PLATE_CHARS)
      chars[i] = PLATE_CHARS:sub(n, n)
    end
    local plate = table.concat(chars)
    if not MySQL.scalar.await('SELECT 1 FROM hpx_vehicles WHERE plate = ? LIMIT 1', { plate }) then
      return plate
    end
  end
  return nil
end

local function getOwned(characterId)
  characterId = math.tointeger(characterId)
  if not characterId then return {} end
  local rows = MySQL.query.await(
    'SELECT id, plate, model, props, stored, garage, state, depot_price FROM hpx_vehicles WHERE character_id = ? ORDER BY id DESC',
    { characterId }
  ) or {}
  for i = 1, #rows do rows[i].props = decodeProps(rows[i].props) end
  return rows
end

lib.callback.register('hpx:vehicles:listOwned', function(source)
  local player = exports.hpx_core:GetPlayer(source)
  if not player then return {} end
  return getOwned(player.charid)
end)

exports('GeneratePlate', generatePlate)
exports('GetOwned', getOwned)

exports('ListOwned', function(source)
  local player = exports.hpx_core:GetPlayer(source)
  return player and getOwned(player.charid) or {}
end)

exports('GetByPlate', function(plate)
  plate = normalizePlate(plate)
  if not validPlate(plate) then return nil end
  local row = MySQL.single.await(
    'SELECT id, character_id, plate, model, props, stored, garage, state, depot_price FROM hpx_vehicles WHERE plate = ? LIMIT 1',
    { plate }
  )
  if row then row.props = decodeProps(row.props) end
  return row
end)

-- Registers a vehicle for a character; returns the new id and plate, or nil and a reason.
exports('AddOwned', function(characterId, model, garage, plate, props)
  characterId = math.tointeger(characterId)
  if not characterId or characterId < 1 then return nil, 'invalid_character' end
  if type(model) ~= 'string' or #model < 1 or #model > 64 or not model:find('^[%w_]+$') then
    return nil, 'invalid_model'
  end
  if type(garage) ~= 'string' or #garage < 1 or #garage > 64 then garage = DEFAULT_GARAGE end

  plate = plate and normalizePlate(plate) or generatePlate()
  if not plate or not validPlate(plate) then return nil, 'invalid_plate' end

  props = type(props) == 'table' and props or {}
  props.plate = plate

  local ok, id = pcall(MySQL.insert.await,
    'INSERT INTO hpx_vehicles (character_id, plate, model, props, stored, garage, state) VALUES (?, ?, ?, ?, 1, ?, ?)',
    { characterId, plate, model, json.encode(props), garage, 'normal' }
  )
  if not ok or not id then return nil, 'plate_taken' end
  return id, plate
end)

exports('SetGarage', function(vehicleId, garage)
  vehicleId = math.tointeger(vehicleId)
  if not vehicleId or type(garage) ~= 'string' or #garage < 1 or #garage > 64 then return false end
  local changed = MySQL.update.await(
    'UPDATE hpx_vehicles SET garage = ?, stored = 1, state = ?, depot_price = 0 WHERE id = ?',
    { garage, 'normal', vehicleId }
  )
  return (changed or 0) > 0
end)

-- Flags a vehicle as impounded; the caller is responsible for removing the world entity.
-- A price of 0 falls back to the garages default depot fee.
exports('Impound', function(plate, price)
  plate = normalizePlate(plate)
  price = math.tointeger(price) or 0
  if not validPlate(plate) or price < 0 then return false end
  local changed = MySQL.update.await(
    'UPDATE hpx_vehicles SET stored = 1, state = ?, depot_price = ? WHERE plate = ?',
    { 'impounded', price, plate }
  )
  return (changed or 0) > 0
end)

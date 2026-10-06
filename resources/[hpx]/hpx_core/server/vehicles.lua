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
  HPXDatabase.ensureColumn('hpx_vehicles', 'depot_price', 'INT UNSIGNED NOT NULL DEFAULT 0')
  HPXDatabase.ensureColumn('hpx_vehicles', 'glovebox', 'LONGTEXT NULL')
  HPXDatabase.ensureColumn('hpx_vehicles', 'trunk', 'LONGTEXT NULL')
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
  local player = HPXServer.GetPlayer(source)
  if not player then return {} end
  return getOwned(player.charid)
end)

exports('GeneratePlate', generatePlate)
exports('GetOwned', getOwned)

exports('ListOwned', function(source)
  local player = HPXServer.GetPlayer(source)
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
  props.model = props.model or joaat(model)

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

-- qbx_vehicles compatible API used by hpx_garages.
-- Numeric states: 0 = out, 1 = garaged, 2 = impounded (stored on the row as stored/state).
local VEHICLE_STATE <const> = { OUT = 0, GARAGED = 1, IMPOUNDED = 2 }
local SELECT_VEHICLE <const> = 'SELECT v.id, v.plate, v.model, v.props, v.stored, v.garage, v.state, v.depot_price, c.citizenid FROM hpx_vehicles v LEFT JOIN hpx_characters c ON c.id = v.character_id'

local function toVehicleState(row)
  if row.state == 'impounded' then return VEHICLE_STATE.IMPOUNDED end
  return (row.stored == 1 or row.stored == true) and VEHICLE_STATE.GARAGED or VEHICLE_STATE.OUT
end

local function fromVehicleState(state)
  if state == VEHICLE_STATE.IMPOUNDED then return 1, 'impounded' end
  if state == VEHICLE_STATE.GARAGED then return 1, 'normal' end
  return 0, 'normal'
end

local function toPlayerVehicle(row)
  local props = decodeProps(row.props)
  props.plate = props.plate or row.plate
  props.model = props.model or tonumber(row.model) or joaat(row.model)
  return {
    id = row.id,
    citizenid = row.citizenid,
    modelName = row.model,
    garage = row.garage,
    state = toVehicleState(row),
    depotPrice = tonumber(row.depot_price) or 0,
    props = props,
  }
end

local function stateClause(states)
  if type(states) == 'number' then states = { states } end
  if type(states) ~= 'table' then return nil end
  local parts = {}
  for _, state in ipairs(states) do
    if state == VEHICLE_STATE.OUT then
      parts[#parts + 1] = '(v.stored = 0)'
    elseif state == VEHICLE_STATE.GARAGED then
      parts[#parts + 1] = "(v.stored = 1 AND v.state <> 'impounded')"
    elseif state == VEHICLE_STATE.IMPOUNDED then
      parts[#parts + 1] = "(v.state = 'impounded')"
    end
  end
  if #parts == 0 then return nil end
  return '(' .. table.concat(parts, ' OR ') .. ')'
end

local function appendFilter(filter, where, params)
  if type(filter) ~= 'table' then return end
  if filter.citizenid ~= nil then
    where[#where + 1] = 'c.citizenid = ?'
    params[#params + 1] = tostring(filter.citizenid)
  end
  if filter.garage ~= nil then
    where[#where + 1] = 'v.garage = ?'
    params[#params + 1] = tostring(filter.garage)
  end
  local clause = stateClause(filter.states)
  if clause then where[#where + 1] = clause end
end

exports('GetPlayerVehicles', function(filter)
  local where, params = {}, {}
  appendFilter(filter, where, params)
  local query = SELECT_VEHICLE
  if #where > 0 then query = query .. ' WHERE ' .. table.concat(where, ' AND ') end
  local rows = MySQL.query.await(query .. ' ORDER BY v.id DESC', params) or {}
  local vehicles = {}
  for i = 1, #rows do vehicles[i] = toPlayerVehicle(rows[i]) end
  return vehicles
end)

exports('GetPlayerVehicle', function(vehicleId, filter)
  vehicleId = math.tointeger(tonumber(vehicleId))
  if not vehicleId then return nil end
  local where, params = { 'v.id = ?' }, { vehicleId }
  appendFilter(filter, where, params)
  local row = MySQL.single.await(SELECT_VEHICLE .. ' WHERE ' .. table.concat(where, ' AND ') .. ' LIMIT 1', params)
  return row and toPlayerVehicle(row) or nil
end)

local function getIdByPlate(plate)
  plate = normalizePlate(plate)
  if not validPlate(plate) then return nil end
  return MySQL.scalar.await('SELECT id FROM hpx_vehicles WHERE plate = ? LIMIT 1', { plate })
end

exports('GetVehicleIdByPlate', getIdByPlate)

-- Saves garage/state/depotPrice/props for the vehicle behind a world entity.
exports('SaveVehicle', function(entity, data)
  if type(entity) ~= 'number' or entity == 0 or not DoesEntityExist(entity) or type(data) ~= 'table' then
    return false
  end

  local id = math.tointeger(tonumber(Entity(entity).state.vehicleid)) or getIdByPlate(GetVehicleNumberPlateText(entity))
  if not id then return false end

  local sets, params = {}, {}
  if data.garage ~= nil then
    sets[#sets + 1] = 'garage = ?'
    params[#params + 1] = tostring(data.garage)
  end
  if data.state ~= nil then
    local stored, status = fromVehicleState(data.state)
    sets[#sets + 1] = 'stored = ?'
    sets[#sets + 1] = 'state = ?'
    params[#params + 1] = stored
    params[#params + 1] = status
  end
  if data.depotPrice ~= nil then
    sets[#sets + 1] = 'depot_price = ?'
    params[#params + 1] = math.max(0, math.floor(tonumber(data.depotPrice) or 0))
  end
  if type(data.props) == 'table' then
    local encoded = json.encode(data.props)
    if not encoded or #encoded > 32768 then return false end
    sets[#sets + 1] = 'props = ?'
    params[#params + 1] = encoded
  end
  if #sets == 0 then return false end

  params[#params + 1] = id
  local changed = MySQL.update.await(('UPDATE hpx_vehicles SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
  return (changed or 0) > 0
end)

-- Spawns a vehicle server side; the owner's client reports the vehicle type and applies props.
exports('SpawnVehicle', function(params)
  if type(params) ~= 'table' then return nil end

  local owner = math.tointeger(tonumber(params.owner))
  local hash = tonumber(params.model) or (type(params.model) == 'string' and joaat(params.model)) or nil
  local spawn = params.spawnSource
  if not owner or not hash or type(spawn) == 'nil' or type(spawn.x) ~= 'number' then return nil end

  local vehicleType = lib.callback.await('hpx:vehicles:getVehicleType', owner, hash)
  if not vehicleType then return nil end

  local heading = type(spawn) == 'vector3' and 0.0 or tonumber(spawn.w) or 0.0
  local entity = CreateVehicleServerSetter(hash, vehicleType, spawn.x, spawn.y, spawn.z, heading)
  if not entity or entity == 0 then return nil end

  local deadline = GetGameTimer() + 5000
  while not DoesEntityExist(entity) do
    if GetGameTimer() > deadline then return nil end
    Wait(0)
  end

  if type(params.props) == 'table' then
    Entity(entity).state:set('setVehicleProperties', params.props, true)
  end

  if params.warp then
    local ped = type(params.warp) == 'number' and params.warp or GetPlayerPed(owner)
    pcall(SetPedIntoVehicle, ped, entity, -1)
  end

  return NetworkGetNetworkIdFromEntity(entity), entity
end)

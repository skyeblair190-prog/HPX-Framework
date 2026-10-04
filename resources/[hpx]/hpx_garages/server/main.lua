local Config <const> = HPXGarages
local Garages <const> = Config.garages

local STATE_NORMAL <const> = 'normal'
local STATE_IMPOUNDED <const> = 'impounded'
local VEHICLE_SLACK <const> = 7.0
local COLUMNS <const> = 'id, character_id, plate, model, props, stored, garage, state, depot_price'

local lastAction = {}

local function fail(reason) return { ok = false, error = reason } end
local function truthy(value) return value == 1 or value == true end

local function normalizePlate(plate)
  return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')):upper()
end

local function decodeProps(raw)
  if type(raw) ~= 'string' or raw == '' then return {} end
  local ok, decoded = pcall(json.decode, raw)
  return ok and type(decoded) == 'table' and decoded or {}
end

local function percent(value, max)
  value = tonumber(value)
  if not value then return 100 end
  return math.floor(math.max(0, math.min(100, value / max * 100)) + 0.5)
end

local function throttled(source)
  local now = GetGameTimer()
  if (lastAction[source] or 0) + Config.actionCooldown > now then return true end
  lastAction[source] = now
  return false
end

AddEventHandler('playerDropped', function()
  lastAction[source] = nil
end)

local function hasGroupAccess(player, groups)
  if not groups then return true end
  local job, gang = player.job or {}, player.gang or {}
  for name, minGrade in pairs(groups) do
    if type(name) == 'number' then name, minGrade = minGrade, 0 end
    if (job.name == name and (tonumber(job.grade) or 0) >= minGrade)
      or (gang.name == name and (tonumber(gang.grade) or 0) >= minGrade) then
      return true
    end
  end
  return false
end

local function getAccess(source, garageName, pointIndex)
  pointIndex = math.tointeger(pointIndex)
  if type(garageName) ~= 'string' or not pointIndex then return nil end

  local player = exports.hpx_core:GetPlayer(source)
  local garage = Garages[garageName]
  if not player or not garage or not hasGroupAccess(player, garage.groups) then return nil end

  local point = garage.accessPoints[pointIndex]
  if not point then return nil end

  local ped = GetPlayerPed(source)
  if not ped or ped == 0 then return nil end
  local limit = (point.radius or Config.interactDistance) + Config.distanceSlack
  if #(GetEntityCoords(ped) - point.coords.xyz) > limit then return nil end

  return player, garage, point, limit
end

local function worldPlates()
  local plates = {}
  for _, vehicle in ipairs(GetAllVehicles()) do
    plates[normalizePlate(GetVehicleNumberPlateText(vehicle))] = true
  end
  return plates
end

local function canAfford(source, amount)
  return (exports.hpx_core:GetMoney(source, 'cash') or 0) >= amount
    or (exports.hpx_core:GetMoney(source, 'bank') or 0) >= amount
end

local function charge(source, amount, reason)
  if (exports.hpx_core:GetMoney(source, 'cash') or 0) >= amount then
    return exports.hpx_core:RemoveMoney(source, 'cash', amount, reason)
  end
  if (exports.hpx_core:GetMoney(source, 'bank') or 0) >= amount then
    return exports.hpx_core:RemoveMoney(source, 'bank', amount, reason)
  end
  return false
end

lib.callback.register('hpx:garages:list', function(source, garageName, pointIndex)
  local player, garage = getAccess(source, garageName, pointIndex)
  if not player then return nil end

  local rows
  if garage.type == 'depot' then
    rows = MySQL.query.await(
      ('SELECT %s FROM hpx_vehicles WHERE character_id = ? AND (stored = 0 OR state = ?) ORDER BY id DESC'):format(COLUMNS),
      { player.charid, STATE_IMPOUNDED }
    )
  elseif garage.shared then
    rows = MySQL.query.await(
      ('SELECT %s FROM hpx_vehicles WHERE garage = ? AND stored = 1 AND state = ? ORDER BY id DESC'):format(COLUMNS),
      { garageName, STATE_NORMAL }
    )
  else
    rows = MySQL.query.await(
      ('SELECT %s FROM hpx_vehicles WHERE character_id = ? AND garage = ? AND stored = 1 AND state = ? ORDER BY id DESC'):format(COLUMNS),
      { player.charid, garageName, STATE_NORMAL }
    )
  end

  local inWorld = garage.type == 'depot' and worldPlates() or {}
  local list = {}
  for _, row in ipairs(rows or {}) do
    if not inWorld[row.plate] then
      local props = decodeProps(row.props)
      local price = 0
      if garage.type == 'depot' then
        price = (tonumber(row.depot_price) or 0) > 0 and row.depot_price or Config.depotFee
      end
      list[#list + 1] = {
        id = row.id,
        plate = row.plate,
        model = row.model,
        engine = percent(props.engineHealth, 1000),
        body = percent(props.bodyHealth, 1000),
        fuel = percent(props.fuelLevel, 100),
        price = price,
        impounded = row.state == STATE_IMPOUNDED,
        mine = row.character_id == player.charid
      }
    end
  end
  return list
end)

lib.callback.register('hpx:garages:retrieve', function(source, vehicleId, garageName, pointIndex)
  if throttled(source) then return fail('busy') end

  vehicleId = math.tointeger(vehicleId)
  if not vehicleId or vehicleId < 1 then return fail('invalid') end

  local player, garage = getAccess(source, garageName, pointIndex)
  if not player then return fail('denied') end

  local row = MySQL.single.await(('SELECT %s FROM hpx_vehicles WHERE id = ? LIMIT 1'):format(COLUMNS), { vehicleId })
  if not row then return fail('not_found') end

  local wasStored = truthy(row.stored) and 1 or 0
  local depotPrice = tonumber(row.depot_price) or 0
  local fee, affected = 0, 0

  if garage.type == 'depot' then
    if row.character_id ~= player.charid then return fail('not_owned') end
    if wasStored == 1 and row.state ~= STATE_IMPOUNDED then return fail('not_impounded') end
    if worldPlates()[row.plate] then return fail('in_world') end

    fee = depotPrice > 0 and depotPrice or Config.depotFee
    if not canAfford(source, fee) then return fail('no_funds') end

    affected = MySQL.update.await(
      'UPDATE hpx_vehicles SET stored = 0, state = ?, depot_price = 0 WHERE id = ? AND character_id = ? AND stored = ? AND state = ?',
      { STATE_NORMAL, row.id, player.charid, wasStored, row.state }
    )
  else
    if wasStored ~= 1 or row.state ~= STATE_NORMAL or row.garage ~= garageName then return fail('not_available') end
    if not garage.shared and row.character_id ~= player.charid then return fail('not_owned') end

    affected = MySQL.update.await(
      'UPDATE hpx_vehicles SET stored = 0 WHERE id = ? AND stored = 1 AND state = ? AND garage = ?',
      { row.id, STATE_NORMAL, garageName }
    )
  end

  if (affected or 0) ~= 1 then return fail('busy') end

  if fee > 0 and not charge(source, fee, 'depot-fee') then
    MySQL.update.await(
      'UPDATE hpx_vehicles SET stored = ?, state = ?, depot_price = ? WHERE id = ?',
      { wasStored, row.state, depotPrice, row.id }
    )
    return fail('no_funds')
  end

  local props = decodeProps(row.props)
  props.plate = row.plate

  TriggerEvent('hpx:garages:vehicleRetrieved', source, row.id, row.plate, garageName)
  return { ok = true, vehicle = { model = row.model, plate = row.plate, props = props } }
end)

lib.callback.register('hpx:garages:park', function(source, netId, props, garageName, pointIndex)
  if throttled(source) then return fail('busy') end

  netId = math.tointeger(netId)
  if not netId or type(props) ~= 'table' then return fail('invalid') end

  local player, garage, point, limit = getAccess(source, garageName, pointIndex)
  if not player or garage.type == 'depot' then return fail('denied') end

  local entity = NetworkGetEntityFromNetworkId(netId)
  if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
    return fail('invalid')
  end
  if #(GetEntityCoords(entity) - point.coords.xyz) > limit + VEHICLE_SLACK then return fail('too_far') end

  local plate = normalizePlate(GetVehicleNumberPlateText(entity))
  local row = MySQL.single.await('SELECT id, character_id, garage, state FROM hpx_vehicles WHERE plate = ? LIMIT 1', { plate })
  if not row or row.state ~= STATE_NORMAL then return fail('not_owned') end
  if row.character_id ~= player.charid and not (garage.shared and row.garage == garageName) then
    return fail('not_owned')
  end

  props.plate = plate
  local encoded = json.encode(props)
  if not encoded or #encoded > Config.maxPropsSize then return fail('invalid') end

  local affected = MySQL.update.await(
    'UPDATE hpx_vehicles SET stored = 1, state = ?, garage = ?, props = ?, depot_price = 0 WHERE id = ?',
    { STATE_NORMAL, garageName, encoded, row.id }
  )
  if (affected or 0) < 1 then return fail('busy') end

  DeleteEntity(entity)
  TriggerEvent('hpx:garages:vehicleStored', source, row.id, plate, garageName)
  return { ok = true }
end)

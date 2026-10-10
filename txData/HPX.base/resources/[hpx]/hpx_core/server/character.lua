HPXServer.Character = {}

local function decode(value, fallback)
  if type(value) == 'table' then return value end
  if type(value) ~= 'string' or value == '' then return fallback end
  local ok, result = pcall(json.decode, value)
  return ok and type(result) == 'table' and result or fallback
end

function HPXServer.Character.Load(source, characterId, isNew)
  local license = HPXGetLicense(source)
  if not license then return nil, 'no_license' end
  characterId = math.tointeger(tonumber(characterId))
  if not characterId or characterId < 1 then return nil, 'invalid_id' end

  local row = MySQL.single.await([[
    SELECT id, license, citizenid, slot, charinfo, money, job, gang, metadata, position, permission, phone
    FROM hpx_characters WHERE id = ? AND license = ? LIMIT 1
  ]], { characterId, license })

  if not row then return nil, 'not_found' end
  if not HPXValidate.source(source) then return nil, 'disconnected' end

  for otherSource, other in pairs(HPXServer.Players) do
    if otherSource ~= source and other.charid == row.id then return nil, 'already_loaded' end
  end
  local previous = HPXServer.GetPlayer(source)
  if previous then
    HPXServer.Character.Save(source)
    TriggerEvent('hpx:server:characterUnloaded', source, previous)
    TriggerClientEvent('hpx:client:characterUnloaded', source)
  end

  row.charinfo = decode(row.charinfo, {})
  row.money = decode(row.money, HPX.copy(HPXConfig.character.defaultMoney))
  row.job = decode(row.job, HPX.copy(HPXConfig.character.defaultJob))
  row.job = HPXServer.ResolveJob(row.job.name, row.job.grade, row.job.onduty) or HPX.copy(HPXConfig.character.defaultJob)
  row.gang = decode(row.gang, HPX.copy(HPXConfig.character.defaultGang))
  row.metadata = decode(row.metadata, {})
  for key, value in pairs(HPXConfig.character.defaultMetadata) do
    if row.metadata[key] == nil then row.metadata[key] = type(value) == 'table' and HPX.copy(value) or value end
  end
  local bloodTypes = HPXConfig.character.bloodTypes
  row.metadata.bloodtype = row.metadata.bloodtype or bloodTypes[math.random(#bloodTypes)]
  row.metadata.fingerprint = row.metadata.fingerprint or HPXServer.GenerateFingerprint()
  row.metadata.walletid = row.metadata.walletid or HPXServer.GenerateWalletId()
  row.position = decode(row.position, nil)

  local player = HPXServer.BuildPlayer(source, row)
  player.phone = row.phone
  HPXServer.SetPlayer(source, player)
  isNew = isNew == true
  TriggerEvent('hpx:server:characterLoaded', source, player, isNew)
  TriggerClientEvent('hpx:client:characterLoaded', source, HPXServer.GetClientData(player), isNew)
  return player
end

function HPXServer.Character.Save(source)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end

  local ped = GetPlayerPed(source)
  if ped and ped ~= 0 then
    local coords = GetEntityCoords(ped)
    if coords.x ~= 0.0 or coords.y ~= 0.0 or coords.z ~= 0.0 then
      player.position = { x = HPX.round(coords.x, 2), y = HPX.round(coords.y, 2), z = HPX.round(coords.z, 2), w = HPX.round(GetEntityHeading(ped), 2) }
    end
  end

  local changed = MySQL.update.await([[
    UPDATE hpx_characters
    SET charinfo = ?, money = ?, job = ?, gang = ?, metadata = ?, position = ?, permission = ?, phone = ?, last_seen = CURRENT_TIMESTAMP
    WHERE id = ? AND license = ?
  ]], {
    json.encode(player.charinfo),
    json.encode(player.money),
    json.encode(player.job),
    json.encode(player.gang),
    json.encode(player.metadata),
    player.position and json.encode(player.position) or nil,
    player.permission,
    player.phone,
    player.charid,
    player.license
  })

  return changed == 1
end

function HPXServer.Character.Unload(source)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end
  HPXServer.Character.Save(source)
  TriggerEvent('hpx:server:characterUnloaded', source, player)
  TriggerClientEvent('hpx:client:characterUnloaded', source)
  HPXServer.RemovePlayer(source)
  return true
end

function HPXServer.Character.List(source)
  local license = HPXGetLicense(source)
  if not license then return nil, 'no_license' end

  local rows = MySQL.query.await(
    'SELECT id, citizenid, slot, charinfo, job, gang, phone, last_seen FROM hpx_characters WHERE license = ? ORDER BY slot ASC',
    { license }
  ) or {}

  for _, row in ipairs(rows) do
    row.charinfo = decode(row.charinfo, {})
    row.job = decode(row.job, {})
    row.gang = decode(row.gang, {})
  end

  return rows
end

local function cleanName(value, max)
  if type(value) ~= 'string' then return nil end
  value = value:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
  if #value < 2 or #value > max or not value:match("^%a[%a '%-]*$") then return nil end
  return (value:lower():gsub("(%a)([%a']*)", function(first, rest) return first:upper() .. rest end))
end

function HPXServer.SanitizeCharInfo(info)
  local firstname, lastname = cleanName(info.firstname, 24), cleanName(info.lastname, 24)
  local nationality = cleanName(info.nationality, 32)
  local gender = type(info.gender) == 'string' and info.gender:lower() or nil
  if gender ~= 'male' and gender ~= 'female' then return nil end

  local day, month, year = tostring(info.birthdate or ''):match('^(%d%d)/(%d%d)/(%d%d%d%d)$')
  day, month, year = tonumber(day), tonumber(month), tonumber(year)
  local currentYear = tonumber(os.date('%Y'))
  if not day or day < 1 or day > 31 or month < 1 or month > 12 or year < 1900 or year > currentYear - 18 then return nil end

  if not firstname or not lastname or not nationality then return nil end
  return { firstname = firstname, lastname = lastname, nationality = nationality, gender = gender, birthdate = info.birthdate }
end

function HPXServer.Character.Create(source, slot, charinfo)
  local license = HPXGetLicense(source)
  if not license then return nil, 'no_license' end
  slot = tonumber(slot)
  if not slot or slot < 1 or slot > HPXConfig.character.maxSlots then return nil, 'invalid_slot' end

  local exists = MySQL.scalar.await('SELECT 1 FROM hpx_characters WHERE license = ? AND slot = ? LIMIT 1', { license, slot })
  if exists then return nil, 'slot_taken' end

  local citizenid = HPXServer.GenerateCitizenId()
  local phone = HPXServer.GeneratePhoneNumber()
  charinfo = type(charinfo) == 'table' and charinfo or {}
  local data = { firstname = 'John', lastname = 'Doe', birthdate = '01/01/2000', gender = 'male', nationality = 'American' }
  if next(charinfo) ~= nil then
    data = HPXServer.SanitizeCharInfo(charinfo)
    if not data then return nil, 'invalid_charinfo' end
  end
  data.cid = slot
  data.phone = phone

  local id = MySQL.insert.await([[
    INSERT INTO hpx_characters
    (license, citizenid, slot, charinfo, money, job, gang, metadata, phone, permission)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
  ]], {
    license, citizenid, slot, json.encode(data),
    json.encode(HPXConfig.character.defaultMoney),
    json.encode(HPXConfig.character.defaultJob),
    json.encode(HPXConfig.character.defaultGang),
    json.encode({}), phone
  })

  if not id then return nil, 'database_error' end
  return HPXServer.Character.Load(source, id, true)
end

function HPXServer.Character.Delete(source, characterId)
  local license = HPXGetLicense(source)
  local player = HPXServer.GetPlayer(source)
  characterId = math.tointeger(tonumber(characterId))
  if not license or not characterId then return false, 'invalid' end
  if player and tonumber(player.charid) == characterId then return false, 'active_character' end
  local changed = MySQL.update.await('DELETE FROM hpx_characters WHERE id = ? AND license = ?', { characterId, license })
  return changed == 1
end

function HPXServer.Character.SetJob(source, name, grade)
  local player = HPXServer.GetPlayer(source)
  if not player or not HPXValidate.text(name, 64) then return false end
  grade = tonumber(grade) or 0
  local job = HPXServer.ResolveJob(name, grade, false)
  if not job then return false end
  player.job = job
  TriggerEvent('hpx:server:jobChanged', source, player.job)
  HPXServer.SyncClient(source)
  return true
end

function HPXServer.Character.SetGang(source, name, grade)
  local player = HPXServer.GetPlayer(source)
  if not player or not HPXValidate.text(name, 64) then return false end
  player.gang = { name = name, label = name, grade = tonumber(grade) or 0 }
  TriggerEvent('hpx:server:gangChanged', source, player.gang)
  HPXServer.SyncClient(source)
  return true
end

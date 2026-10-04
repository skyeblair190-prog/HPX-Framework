HPXServer.Character = {}

local function decode(value, fallback)
  if type(value) == 'table' then return value end
  if type(value) ~= 'string' or value == '' then return fallback end
  local ok, result = pcall(json.decode, value)
  return ok and type(result) == 'table' and result or fallback
end

function HPXServer.Character.Load(source, characterId)
  local license = HPXGetLicense(source)
  if not license then return nil, 'no_license' end

  local row = MySQL.single.await([[
    SELECT id, license, citizenid, slot, charinfo, money, job, gang, metadata, position, permission, phone
    FROM hpx_characters WHERE id = ? AND license = ? LIMIT 1
  ]], { characterId, license })

  if not row then return nil, 'not_found' end

  row.charinfo = decode(row.charinfo, {})
  row.money = decode(row.money, HPX.copy(HPXConfig.character.defaultMoney))
  row.job = decode(row.job, HPX.copy(HPXConfig.character.defaultJob))
  row.gang = decode(row.gang, HPX.copy(HPXConfig.character.defaultGang))
  row.metadata = decode(row.metadata, {})

  local player = HPXServer.BuildPlayer(source, row)
  player.phone = row.phone
  HPXServer.SetPlayer(source, player)
  TriggerEvent('hpx:server:characterLoaded', source, player)
  return player
end

function HPXServer.Character.Save(source)
  local player = HPXServer.GetPlayer(source)
  if not player then return false end

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

function HPXServer.Character.Create(source, slot, charinfo)
  local license = HPXGetLicense(source)
  if not license then return nil, 'no_license' end
  slot = tonumber(slot)
  if not slot or slot < 1 or slot > HPXConfig.character.maxSlots then return nil, 'invalid_slot' end

  local exists = MySQL.scalar.await('SELECT 1 FROM hpx_characters WHERE license = ? AND slot = ? LIMIT 1', { license, slot })
  if exists then return nil, 'slot_taken' end

  local citizenid = HPXServer.GenerateCitizenId()
  local phone = HPXServer.GeneratePhoneNumber()
  local data = {
    firstname = tostring(charinfo and charinfo.firstname or 'John'),
    lastname = tostring(charinfo and charinfo.lastname or 'Doe'),
    birthdate = tostring(charinfo and charinfo.birthdate or '01/01/2000'),
    gender = tostring(charinfo and charinfo.gender or 'male'),
    nationality = tostring(charinfo and charinfo.nationality or 'Los Santos')
  }

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
  return HPXServer.Character.Load(source, id)
end

function HPXServer.Character.Delete(source, characterId)
  local license = HPXGetLicense(source)
  local player = HPXServer.GetPlayer(source)
  if player and tonumber(player.charid) == tonumber(characterId) then return false, 'active_character' end
  local changed = MySQL.update.await('DELETE FROM hpx_characters WHERE id = ? AND license = ?', { characterId, license })
  return changed == 1
end

function HPXServer.Character.SetJob(source, name, grade)
  local player = HPXServer.GetPlayer(source)
  if not player or not HPXValidate.text(name, 64) then return false end
  grade = tonumber(grade) or 0
  player.job = { name = name, label = name, grade = grade, onduty = false, payment = 0 }
  TriggerEvent('hpx:server:jobChanged', source, player.job)
  return true
end

function HPXServer.Character.SetGang(source, name, grade)
  local player = HPXServer.GetPlayer(source)
  if not player or not HPXValidate.text(name, 64) then return false end
  player.gang = { name = name, label = name, grade = tonumber(grade) or 0 }
  return true
end

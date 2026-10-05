-- Methods are stored as own fields (not through a metatable) so they survive
-- the export boundary as function references. Each one resolves the live player
-- by source, so calls made on an exported snapshot always act on current data.
local function attachMethods(player)
  local source = player.source

  local function current()
    return HPXServer.GetPlayer(source)
  end

  player.GetSource = function() return source end

  player.GetCharacterId = function()
    local p = current()
    return p and p.charid
  end

  player.GetCitizenId = function()
    local p = current()
    return p and p.citizenid
  end

  player.GetName = function()
    local p = current()
    if not p then return nil end
    local c = p.charinfo or {}
    local name = ('%s %s'):format(c.firstname or '', c.lastname or '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
  end

  player.GetJob = function()
    local p = current()
    return p and p.job
  end

  player.GetGang = function()
    local p = current()
    return p and p.gang
  end

  player.GetMetadata = function(_, key)
    local p = current()
    if not p then return nil end
    if key == nil then return p.metadata end
    return p.metadata[key]
  end

  player.SetMetadata = function(_, key, value)
    local p = current()
    if not p or type(key) ~= 'string' then return false end
    p.metadata[key] = value
    return true
  end

  player.GetMoney = function(_, kind)
    local p = current()
    return p and p.money[kind] or 0
  end

  player.SetMoney = function(_, kind, amount)
    local p = current()
    if not p or not HPXValidate.moneyType(kind) then return false end
    amount = tonumber(amount)
    if not amount or amount < 0 then return false end
    p.money[kind] = HPX.round(amount, 2)
    return true
  end

  player.AddMoney = function(_, kind, amount, reason)
    return HPXServer.Money.Change(source, kind, math.abs(tonumber(amount) or 0), reason or 'unknown')
  end

  player.RemoveMoney = function(_, kind, amount, reason)
    return HPXServer.Money.Change(source, kind, -math.abs(tonumber(amount) or 0), reason or 'unknown')
  end

  player.SetJob = function(_, job, grade)
    return HPXServer.Character.SetJob(source, job, grade)
  end

  player.SetGang = function(_, gang, grade)
    return HPXServer.Character.SetGang(source, gang, grade)
  end

  player.Save = function()
    return HPXServer.Character.Save(source)
  end

  player.Drop = function(_, reason)
    DropPlayer(source, reason or 'Disconnected')
  end
end

function HPXServer.BuildPlayer(source, row)
  local player = {
    source = source,
    license = row.license,
    charid = row.id,
    citizenid = row.citizenid,
    charinfo = row.charinfo or {},
    money = row.money or HPX.copy(HPXConfig.character.defaultMoney),
    job = row.job or HPX.copy(HPXConfig.character.defaultJob),
    gang = row.gang or HPX.copy(HPXConfig.character.defaultGang),
    metadata = row.metadata or {},
    position = row.position,
    state = {},
    permission = tonumber(row.permission) or 0
  }
  attachMethods(player)
  return player
end

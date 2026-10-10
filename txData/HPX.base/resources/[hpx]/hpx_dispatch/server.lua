local calls, callOrder = {}, {}
local nextCallId = 0
local units, memberUnit = {}, {}
local nextUnitId = 0
local lastCall = {}

local jobLabels = {}
for _, job in ipairs(Config.EmergencyJobs) do jobLabels[job.name] = job.displayname end

local function getPlayer(source)
  return exports.hpx_core:GetPlayer(source)
end

local function emergencyJob(source)
  local player = getPlayer(source)
  local name = player and type(player.job) == 'table' and player.job.name
  return name and jobLabels[name] and name or nil
end

local function fullName(player)
  local info = player.charinfo or {}
  return ((('%s %s'):format(info.firstname or '', info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function callsignOf(player)
  return type(player.metadata) == 'table' and player.metadata.callsign or 'N/A'
end

local function notify(source, message, kind)
  TriggerClientEvent('hpx_dispatch:client:notify', source, message, kind or 'inform')
end

local function str(value, max)
  if type(value) ~= 'string' then return nil end
  value = value:gsub('[%c<>]', ''):sub(1, max)
  return value ~= '' and value or nil
end

local function num(value)
  if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return nil end
  return value
end

local function sanitizeValues(list)
  local out = {}
  if type(list) ~= 'table' then return out end
  for i = 1, math.min(#list, 6) do
    local entry = list[i]
    if type(entry) == 'table' then
      local text = str(entry.text, 40)
      local icon = type(entry.icon) == 'string' and #entry.icon <= 40 and entry.icon:match('^fa%-%a+ fa%-[%w%-]+$')
      if text then out[#out + 1] = { text = text, icon = icon or 'fa-solid fa-circle-info' } end
    end
  end
  return out
end

local function sanitizeCall(data)
  if type(data) ~= 'table' then return nil end

  local title = str(data.title, 60)
  local coords = data.coords
  local x, y, z = num(coords and coords.x), num(coords and coords.y), num(coords and coords.z)
  if not title or not x or not y or not z then return nil end

  local jobs, seen = {}, {}
  if type(data.jobs) == 'table' then
    for _, job in ipairs(data.jobs) do
      if type(job) == 'string' and jobLabels[job] and not seen[job] then
        seen[job] = true
        jobs[#jobs + 1] = job
      end
    end
  end
  if #jobs == 0 then return nil end

  local blip = type(data.blip) == 'table' and data.blip or {}
  return {
    title = title,
    code = str(data.code, 16) or '',
    values = sanitizeValues(data.values),
    valuestwo = {},
    jobs = jobs,
    active = false,
    coords = { x = x, y = y, z = z },
    blip = {
      blipid = math.min(math.max(math.floor(num(blip.blipid) or 1), 0), 900),
      blipcolor = math.min(math.max(math.floor(num(blip.blipcolor) or 1), 0), 85)
    }
  }
end

local function canSee(source, call)
  local job = emergencyJob(source)
  if not job then return false end
  for _, name in ipairs(call.jobs) do
    if name == job then return true end
  end
  return false
end

local function addCall(data)
  local call = sanitizeCall(data)
  if not call then return nil end

  nextCallId = nextCallId + 1
  call.dispatchnumber = nextCallId
  call.date = os.date('%Y-%m-%d %H:%M:%S')

  calls[nextCallId] = call
  callOrder[#callOrder + 1] = nextCallId
  if #callOrder > Config.MaxCalls then
    calls[table.remove(callOrder, 1)] = nil
  end

  for _, player in ipairs(exports.hpx_core:GetPlayersData()) do
    if canSee(player.source, call) then
      TriggerClientEvent('hpx_dispatch:client:dispatch', player.source, call)
    end
  end

  return call
end

RegisterNetEvent('hpx_dispatch:server:add', function(data)
  local source = source
  local player = getPlayer(source)
  if not player then return end

  local now = GetGameTimer()
  if lastCall[source] and now - lastCall[source] < Config.CallCooldown then return end
  lastCall[source] = now

  local call = sanitizeCall(data)
  if not call then return end

  local ped = GetPlayerPed(source)
  if ped ~= 0 then
    local pos = GetEntityCoords(ped)
    local dx, dy = pos.x - call.coords.x, pos.y - call.coords.y
    if dx * dx + dy * dy > Config.MaxCallDistance * Config.MaxCallDistance then return end
  end

  addCall(data)
end)

lib.callback.register('hpx_dispatch:getDispatchs', function(source)
  local list = {}
  for _, id in ipairs(callOrder) do
    local call = calls[id]
    if call and canSee(source, call) then list[#list + 1] = call end
  end
  return list
end)

lib.callback.register('hpx_dispatch:getJobPlayers', function(source)
  if not emergencyJob(source) then return {} end

  local players = exports.hpx_core:GetPlayersData()
  local result = {}
  for _, job in ipairs(Config.EmergencyJobs) do
    local officers = {}
    for _, player in ipairs(players) do
      if type(player.job) == 'table' and player.job.name == job.name then
        officers[#officers + 1] = {
          source = player.source,
          name = fullName(player),
          callsign = callsignOf(player),
          job = player.job
        }
      end
    end
    result[#result + 1] = { name = job.name, displayname = job.displayname, officers = officers }
  end
  return result
end)

local function removeMember(source)
  local unitId = memberUnit[source]
  if not unitId then return end
  memberUnit[source] = nil

  local unit = units[unitId]
  if not unit then return end

  for index, officer in ipairs(unit.officer) do
    if officer.source == source then
      table.remove(unit.officer, index)
      break
    end
  end
  if #unit.officer == 0 then units[unitId] = nil end
end

local function deleteUnit(source)
  local unitId = memberUnit[source]
  if not unitId then return true end

  local unit = units[unitId]
  if not unit then
    memberUnit[source] = nil
    return true
  end
  if unit.unithead ~= source then return false end

  for _, officer in ipairs(unit.officer) do memberUnit[officer.source] = nil end
  units[unitId] = nil
  return true
end

local function leaveUnit(source)
  local unitId = memberUnit[source]
  local unit = unitId and units[unitId]
  if unit and unit.unithead == source then return deleteUnit(source) end
  removeMember(source)
  return true
end

lib.callback.register('hpx_dispatch:createUnit', function(source, data)
  local job = emergencyJob(source)
  local me = getPlayer(source)
  if not job or not me or memberUnit[source] or type(data) ~= 'table' then return false end

  local name, callname = str(data.name, 30), str(data.callcode, 10)
  if not name or not callname then return false end

  local officers, added = {}, { [source] = true }
  if type(data.personlist) == 'table' then
    for _, value in ipairs(data.personlist) do
      local target = math.tointeger(tonumber(value))
      local player = target and not added[target] and not memberUnit[target] and getPlayer(target)
      if player and #officers < Config.MaxUnitMembers - 1 and emergencyJob(target) == job then
        added[target] = true
        officers[#officers + 1] = { callsign = callsignOf(player), name = fullName(player), source = target, unithead = false }
      end
    end
  end
  officers[#officers + 1] = { callsign = callsignOf(me), name = fullName(me), source = source, unithead = true }

  nextUnitId = nextUnitId + 1
  units[nextUnitId] = {
    id = nextUnitId,
    active = true,
    unithead = source,
    officer = officers,
    name = name,
    callname = callname,
    job = job
  }
  for _, officer in ipairs(officers) do memberUnit[officer.source] = nextUnitId end
  return true
end)

lib.callback.register('hpx_dispatch:getUnits', function(source)
  if not emergencyJob(source) then return {} end

  local ids = {}
  for id in pairs(units) do ids[#ids + 1] = id end
  table.sort(ids)

  local result = {}
  for _, job in ipairs(Config.EmergencyJobs) do
    local jobUnits = {}
    for _, id in ipairs(ids) do
      if units[id].job == job.name then jobUnits[#jobUnits + 1] = units[id] end
    end
    result[#result + 1] = { name = job.name, displayname = job.displayname, jobunits = jobUnits }
  end
  return result
end)

lib.callback.register('hpx_dispatch:getMyUnit', function(source)
  local unitId = memberUnit[source]
  local unit = unitId and units[unitId]
  if not unit then return false end
  return { unitid = unitId, unithead = unit.unithead == source, hasaunit = true }
end)

lib.callback.register('hpx_dispatch:canAddtoUnit', function(source, id)
  id = math.tointeger(tonumber(id))
  local job = emergencyJob(source)
  if not job or not id or id == source or memberUnit[id] then return false end
  return getPlayer(id) ~= nil and emergencyJob(id) == job
end)

lib.callback.register('hpx_dispatch:leaveUnit', function(source) return leaveUnit(source) end)
lib.callback.register('hpx_dispatch:deleteUnit', function(source) return deleteUnit(source) end)

lib.callback.register('hpx_dispatch:getLocation', function(source, id)
  local call = calls[math.tointeger(tonumber(id))]
  return call and canSee(source, call) and call.coords or nil
end)

RegisterNetEvent('hpx_dispatch:server:setActive', function(id)
  local source = source
  local call = calls[math.tointeger(tonumber(id))]
  if not call or not canSee(source, call) then return end

  local unit = units[memberUnit[source]]
  if not unit then
    notify(source, "You don't have a unit. You can't activate the dispatch.", 'error')
    return
  end

  call.active = true
  call.valuestwo = { { text = unit.callname, icon = 'fa-solid fa-walkie-talkie' } }
end)

RegisterCommand('callsign', function(source, args)
  if source == 0 then return end
  local player = getPlayer(source)
  local sign = str(table.concat(args, ' '), 10)
  if not player or not emergencyJob(source) or not sign then return end

  player:SetMetadata('callsign', sign)
  notify(source, ('Callsign set to %s.'):format(sign), 'success')
end, false)

AddEventHandler('playerDropped', function()
  leaveUnit(source)
  lastCall[source] = nil
end)

exports('sendDispatch', addCall)
exports('CreateCall', addCall)

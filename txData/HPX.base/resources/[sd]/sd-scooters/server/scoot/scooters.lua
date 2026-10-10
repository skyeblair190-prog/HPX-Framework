---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'
---@type table Bunker cache (server/scoot/bunkers.lua): home lookups and the delete hook.
local bunkers = require 'server.scoot.bunkers'
---@type table Station cache + slot bookkeeping (server/scoot/stations.lua): dock poses and the delete hook.
local stations = require 'server.scoot.stations'

---@type table Scooter tuning (configs/shared/scooters.lua).
local CFG = config.Scooters
---@type integer Vehicle model hash.
local MODEL = joaat(CFG.Model)
---@type string Entity state bag key clients and other resources read to recognise a fleet scooter.
local STATE_KEY = 'sd_scoot'
---@type string Entity state bag key carrying the dock pose while a scooter is parked in a station.
local DOCK_KEY = 'sd_scoot_dock'

---@type table Customisation catalogue + validation (shared/extras.lua).
local extras = require 'shared.extras'
---@type table Scooters module; the table returned at end of file.
local scooters = {}

---@type table<integer, table> id -> { row = table, entity = integer|nil }. The row is the database
---shape with camelCase keys; `entity` is the server handle while the vehicle exists.
local cache = {}
---@type fun(entry: table)[] Listeners told after a vehicle is (re)created, so rentals can lock it.
local spawnListeners = {}

---Finite number or nil.
---@param n any
---@return number|nil
local function finite(n)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n + 0.0
end

---Colour index inside Config.Scooters.Colours, or nil.
---@param colour any
---@return integer|nil
local function validColour(colour)
    colour = math.tointeger(tonumber(colour) or 0)
    if not colour or colour < 1 or colour > #CFG.Colours then return nil end
    return colour
end

---Live coordinates when the entity exists, else the stored ones.
---@param entry table
---@return number x, number y, number z, number heading
local function whereIs(entry)
    local e = entry.entity
    if e and DoesEntityExist(e) then
        local c = GetEntityCoords(e)
        return c.x, c.y, c.z, GetEntityHeading(e)
    end
    local r = entry.row
    return r.x, r.y, r.z, r.heading
end

---The shape the panel and the exports see.
---@param entry table
---@return table
local function view(entry)
    local r = entry.row
    local x, y, z, heading = whereIs(entry)
    return {
        id = r.id, plate = r.plate, colour = r.colour, customization = r.customization, bunkerId = r.bunkerId, status = r.status,
        battery = math.tointeger(math.floor(tonumber(r.battery) or 100)) or 100, stationId = r.stationId, slot = r.slot, chargeTarget = r.chargeTarget,
        x = x, y = y, z = z, heading = heading,
        exists = entry.entity ~= nil and DoesEntityExist(entry.entity),
        locked = entry.entity ~= nil and DoesEntityExist(entry.entity) and Entity(entry.entity).state.doorslockstate == 2 or false,
    }
end

---Create the networked vehicle for a row and stamp plate, paint and state bag on it.
---@param entry table
---@return integer|nil entity
local function spawn(entry)
    local r = entry.row
    local veh = CreateVehicleServerSetter(MODEL, 'bike', r.x, r.y, r.z, r.heading)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        log.error('scooters', 'CreateVehicleServerSetter failed for #%d %s', r.id, r.plate)
        return nil
    end
    local paint = CFG.Colours[r.colour] or CFG.Colours[1]
    SetVehicleColours(veh, paint.primary, paint.primary)
    SetVehicleNumberPlateText(veh, r.plate)
    Entity(veh).state:set(STATE_KEY, { id = r.id, colour = r.colour, customization = r.customization }, true)
    Entity(veh).state:set('fuel', (r.battery or 100) + 0.0, true)
    if r.stationId and r.status == 'charging' then
        SetEntityHeading(veh, r.heading)
        Entity(veh).state:set(DOCK_KEY, { x = r.x, y = r.y, z = r.z, heading = r.heading, station = r.stationId, slot = r.slot, phase = 'docked' }, true)
        FreezeEntityPosition(veh, true)
    end
    entry.entity = veh
    for _, fn in ipairs(spawnListeners) do
        local okay, err = pcall(fn, entry)
        if not okay then log.error('scooters', 'onSpawn listener failed: %s', tostring(err)) end
    end
    return veh
end

---Register a listener for vehicle creation (boot, create, respawn).
---@param fn fun(entry: table)
function scooters.onSpawn(fn)
    spawnListeners[#spawnListeners + 1] = fn
end

---Delete a scooter's vehicle if it exists. Idempotent.
---@param entry table
local function despawn(entry)
    if entry.entity and DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    entry.entity = nil
end

---Next free plate for the configured prefix, e.g. SCOOT007.
---@return string
local function nextPlate()
    local n = store.scooters.highestPlateNumber(CFG.PlatePrefix) + 1
    return ('%s%03d'):format(CFG.PlatePrefix, n)
end

---Write back the position of every scooter that moved more than a metre since the last save.
local function syncPositions()
    for _, entry in pairs(cache) do
        local e = entry.entity
        if e and DoesEntityExist(e) then
            local r = entry.row
            local c = GetEntityCoords(e)
            if #(c - vector3(r.x, r.y, r.z)) > 1.0 then
                r.x, r.y, r.z, r.heading = c.x, c.y, c.z, GetEntityHeading(e)
                store.scooters.setPosition(r.id, r.x, r.y, r.z, r.heading)
            end
        end
    end
end

---Load the table, spawn every scooter, hook bunker deletions and start the position sync. Called
---once from server/main.lua.
function scooters.boot()
    cache = {}
    local fullAt = config.Battery.FullAt
    local removed, restocked = 0, 0
    for _, r in ipairs(store.scooters.all()) do
        r.customization = extras.decode(r.customization)
        r.x, r.y, r.z, r.heading = r.x + 0.0, r.y + 0.0, r.z + 0.0, (r.heading or 0) + 0.0
        r.battery = math.tointeger(math.floor(tonumber(r.battery) or 100)) or 100
        r.chargeTarget = math.tointeger(tonumber(r.chargeTarget) or 0) or nil
        if r.chargeTarget and (r.chargeTarget <= r.battery or r.chargeTarget <= 0) then r.chargeTarget = nil end
        if r.stationId then
            local st = stations.get(r.stationId)
            local slot = math.tointeger(tonumber(r.slot) or 0) or 0
            if st and slot >= 1 and not st.slots[slot] and stations.occupy(st.id, slot, r.id, r.battery >= fullAt, { plate = r.plate, colour = r.colour, battery = r.battery, target = r.chargeTarget }) then
                r.status = 'charging'
                r.x, r.y, r.z, r.heading = stations.slotPose(st, slot)
            else
                r.stationId, r.slot = nil, nil
                if r.status == 'charging' then r.status = 'available' end
                store.scooters.setDock(r.id, nil, nil)
            end
        end
        if not CFG.KeepOnRestart and r.status ~= 'charging' then
            store.scooters.delete(r.id)
            removed = removed + 1
            local dispensed = type(r.createdBy) == 'string' and r.createdBy:sub(1, 9) == 'dispense:'
            local home = dispensed and r.bunkerId and bunkers.get(r.bunkerId) or nil
            if home then
                bunkers.adjustStock(home.id, 1)
                restocked = restocked + 1
            end
        else
            local entry = { row = r }
            cache[r.id] = entry
            spawn(entry)
        end
    end
    if removed > 0 then log.info('scooters', 'cleared %d scooter(s) left out in the world, %d back into bunker stock', removed, restocked) end
    bunkers.onRemoved(function(bunkerId)
        for _, entry in pairs(cache) do
            if entry.row.bunkerId == bunkerId then entry.row.bunkerId = nil end
        end
        store.scooters.detachBunker(bunkerId)
    end)
    stations.onMoved(function(stationId)
        local st = stations.get(stationId)
        if not st then return end
        for _, entry in pairs(cache) do
            local r = entry.row
            if r.stationId == stationId and r.slot then
                r.x, r.y, r.z, r.heading = stations.slotPose(st, r.slot)
                store.scooters.setPosition(r.id, r.x, r.y, r.z, r.heading)
                local e = entry.entity
                if e and DoesEntityExist(e) then
                    FreezeEntityPosition(e, false)
                    SetEntityCoords(e, r.x, r.y, r.z, false, false, false, false)
                    SetEntityHeading(e, r.heading)
                    FreezeEntityPosition(e, true)
                    Entity(e).state:set(DOCK_KEY, { x = r.x, y = r.y, z = r.z, heading = r.heading, station = st.id, slot = r.slot, phase = 'docked' }, true)
                end
            end
        end
    end)
    stations.onRemoved(function(stationId)
        for _, entry in pairs(cache) do
            if entry.row.stationId == stationId then
                entry.row.stationId, entry.row.slot = nil, nil
                if entry.row.status == 'charging' then entry.row.status = 'available' end
            end
        end
        store.scooters.detachStation(stationId)
    end)
    CreateThread(function()
        while true do
            Wait(CFG.SaveInterval * 1000)
            syncPositions()
        end
    end)
    CreateThread(function()
        while true do
            Wait(CFG.HealInterval * 1000)
            for _, entry in pairs(cache) do
                if entry.row.status ~= 'rented' and not (entry.entity and DoesEntityExist(entry.entity)) then
                    entry.entity = nil
                    if spawn(entry) then log.warn('scooters', 'respawned #%d %s: its vehicle had disappeared', entry.row.id, entry.row.plate) end
                end
            end
        end
    end)
end

---Delete the vehicles of every scooter that is not rented so clients can drop the model (the
---/scootflush flow). Rows stay; spawnMissing brings the vehicles back.
---@return integer count despawned
function scooters.despawnIdle()
    local n = 0
    for _, entry in pairs(cache) do
        if entry.row.status ~= 'rented' and entry.entity then
            despawn(entry)
            n = n + 1
        end
    end
    return n
end

---Spawn a vehicle for every scooter that has none (after despawnIdle, or a vanished vehicle).
---@return integer count spawned
function scooters.spawnMissing()
    local n = 0
    for _, entry in pairs(cache) do
        if not (entry.entity and DoesEntityExist(entry.entity)) then
            entry.entity = nil
            if spawn(entry) then n = n + 1 end
        end
    end
    return n
end

---Overwrite a scooter's stored rest position (and heading) without touching the live entity.
---Used by the dispense flow, which creates the vehicle out of sight and only later parks it.
---@param id integer
---@param x number
---@param y number
---@param z number
---@param heading number
function scooters.setRestPosition(id, x, y, z, heading)
    local entry = scooters.get(id)
    if not entry then return end
    local r = entry.row
    r.x, r.y, r.z, r.heading = x + 0.0, y + 0.0, z + 0.0, (heading or 0.0) + 0.0
    store.scooters.setPosition(r.id, r.x, r.y, r.z, r.heading)
end

---The live cache, for modules that walk every scooter each tick (battery). Entries are shared,
---not copied; callers mutate rows only through this module's functions.
---@return table<integer, table>
function scooters.entries()
    return cache
end

---Set a scooter's battery, cached and written back (not awaited).
---@param id integer
---@param value number 0..100; floored to a whole percent
function scooters.setBattery(id, value)
    local entry = scooters.get(id)
    if not entry then return end
    local level = math.max(0, math.min(100, math.tointeger(math.floor(tonumber(value) or 0)) or 0))
    if entry.row.battery == level then return end
    entry.row.battery = level
    store.scooters.setBattery(entry.row.id, level)
    if entry.entity and DoesEntityExist(entry.entity) then
        Entity(entry.entity).state:set('fuel', level + 0.0, true)
    end
end

---Set (or clear with nil) the percent a docked scooter is paid to charge to. Cached and written
---back; the station slot mirror is the caller's (stations.setTarget).
---@param id integer
---@param target integer|nil
function scooters.setChargeTarget(id, target)
    local entry = scooters.get(id)
    if not entry then return end
    if target ~= nil then target = math.max(1, math.min(100, math.tointeger(math.floor(tonumber(target) or 0)) or 0)) end
    if entry.row.chargeTarget == target then return end
    entry.row.chargeTarget = target
    store.scooters.setChargeTarget(entry.row.id, target)
end

---Park a scooter in a station slot: the vehicle is moved into the slot pose, the stored rest
---position follows it and the row becomes `charging`. The station's own slot table is the
---caller's to update (stations.occupy), so one function never half-applies a dock. A rider still
---on the seat is asked to step off first and the move waits for them.
---@param id integer
---@param stationId integer
---@param slot integer
---@return boolean ok
function scooters.dock(id, stationId, slot)
    local entry = scooters.get(id)
    local st = stations.get(stationId)
    if not entry or not st then return false end
    local r = entry.row
    r.x, r.y, r.z, r.heading = stations.slotPose(st, slot)
    r.stationId, r.slot, r.status = st.id, slot, 'charging'
    store.scooters.setPosition(r.id, r.x, r.y, r.z, r.heading)
    store.scooters.setDock(r.id, st.id, slot)
    store.scooters.setStatus(r.id, 'charging')
    local e = entry.entity
    if e and DoesEntityExist(e) then
        local x, y, z, heading = r.x, r.y, r.z, r.heading
        local anim = config.Stations.Anim
        local function park()
            if not DoesEntityExist(e) or r.stationId ~= st.id then return end
            Entity(e).state:set(DOCK_KEY, { x = x, y = y, z = z, heading = heading, station = st.id, slot = slot, phase = 'in' }, true)
            local clamp = config.Stations.PlugAnim
            SetTimeout(anim.Hoop * 2 + anim.Approach + anim.Slide + anim.Settle + (clamp and clamp.SlideMs + clamp.SwingMs or 0), function()
                if not DoesEntityExist(e) or r.stationId ~= st.id or r.slot ~= slot then return end
                FreezeEntityPosition(e, true)
                Entity(e).state:set(DOCK_KEY, { x = x, y = y, z = z, heading = heading, station = st.id, slot = slot, phase = 'docked' }, true)
            end)
        end
        local rider = GetPedInVehicleSeat(e, -1)
        local src = rider and rider ~= 0 and NetworkGetEntityOwner(rider) or nil
        if src and src > 0 and GetPlayerPed(src) == rider then
            TriggerClientEvent('sd_scoot:client:leaveVehicle', src)
            SetTimeout(1500, park)
        else
            park()
        end
    end
    return true
end

---Take a scooter out of its slot bookkeeping (the vehicle stays where it is) and make it available.
---@param id integer
function scooters.undock(id)
    local entry = scooters.get(id)
    if not entry then return end
    local r = entry.row
    local stationId, slot = r.stationId, r.slot
    r.stationId, r.slot, r.status = nil, nil, 'available'
    store.scooters.setDock(r.id, nil, nil)
    store.scooters.setStatus(r.id, 'available')
    if r.chargeTarget then scooters.setChargeTarget(r.id, nil) end
    local e = entry.entity
    if not e or not DoesEntityExist(e) then return end
    local pose = Entity(e).state[DOCK_KEY]
    if type(pose) ~= 'table' or not stationId then
        Entity(e).state:set(DOCK_KEY, false, true)
        return
    end
    FreezeEntityPosition(e, false)
    local anim = config.Stations.Anim
    Entity(e).state:set(DOCK_KEY, { x = pose.x, y = pose.y, z = pose.z, heading = pose.heading, station = stationId, slot = slot, phase = 'out' }, true)
    local clamp = config.Stations.PlugAnim
    SetTimeout(anim.Hoop + anim.Out + anim.Settle + (clamp and clamp.ReleaseMs + clamp.SlideMs or 0), function()
        if DoesEntityExist(e) and not r.stationId then Entity(e).state:set(DOCK_KEY, false, true) end
    end)
end

---Every scooter as a view, sorted by id.
---@return table[]
function scooters.all()
    local out = {}
    for _, entry in pairs(cache) do out[#out + 1] = view(entry) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---Cached scooter entry by id.
---@param id integer
---@return table|nil entry
function scooters.get(id)
    return cache[tonumber(id) or -1]
end

---The fleet entry whose live vehicle is this entity, or nil for a scooter the fleet does not own.
---@param entity integer
---@return table|nil entry
function scooters.byEntity(entity)
    if not entity or entity == 0 then return nil end
    for _, entry in pairs(cache) do
        if entry.entity == entity then return entry end
    end
    return nil
end

---Take an existing sd_scoot vehicle into the fleet: a row is written for it, its plate is made
---unique, its paint is matched to the nearest configured colour and it starts on the adopted
---battery level. Used when someone docks a scooter the fleet never spawned.
---@param entity integer server handle of a vehicle that already exists
---@param createdBy string|nil
---@return table|false entry
---@return string|nil errKey
function scooters.adopt(entity, createdBy)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false, 'err.no_scooter' end
    if GetEntityModel(entity) ~= MODEL then return false, 'err.not_a_scooter' end
    local existing = scooters.byEntity(entity)
    if existing then return existing end
    local c = GetEntityCoords(entity)
    local primary = GetVehicleColours(entity)
    local colour = 1
    for i, col in ipairs(CFG.Colours) do
        if col.primary == primary then colour = i break end
    end
    local row = {
        customization = extras.decode(nil),
        plate = nextPlate(), colour = colour, bunkerId = nil,
        x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, heading = GetEntityHeading(entity) + 0.0,
        status = 'available', createdBy = createdBy,
        battery = math.max(0, math.min(100, math.tointeger(tonumber(config.Battery.AdoptedLevel) or 100) or 100)),
    }
    row.id = store.scooters.insert(row)
    store.scooters.setBattery(row.id, row.battery)
    local entry = { row = row, entity = entity }
    cache[row.id] = entry
    SetVehicleNumberPlateText(entity, row.plate)
    Entity(entity).state:set(STATE_KEY, { id = row.id, colour = row.colour, customization = row.customization }, true)
    for _, fn in ipairs(spawnListeners) do
        local okay, err = pcall(fn, entry)
        if not okay then log.error('scooters', 'onSpawn listener failed: %s', tostring(err)) end
    end
    log.info('scooters', 'adopted #%d %s into the fleet by %s', row.id, row.plate, tostring(createdBy))
    return entry
end

---Number of cached scooters.
---@return integer
function scooters.count()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end

---Insert + spawn a scooter at explicit coordinates (the placement tool's result).
---@param data table { x, y, z, heading, colour, bunkerId|nil }
---@param createdBy string|nil
---@return table|false view; false rather than nil so the error survives the export boundary
---@return string|nil errKey
function scooters.create(data, createdBy)
    local x, y, z = finite(data and data.x), finite(data and data.y), finite(data and data.z)
    if not (x and y and z) then return false, 'err.bad_coords' end
    local colour = validColour(data.colour)
    if not colour then return false, 'err.bad_colour' end
    local bunkerId = nil
    if data.bunkerId ~= nil and data.bunkerId ~= false then
        local b = bunkers.get(data.bunkerId)
        if not b then return false, 'err.no_bunker' end
        bunkerId = b.id
    end
    local customization, extraErr = extras.normalise(data.customization)
    if not customization then return false, extraErr end
    local row = {
        customization = customization,
        plate = nextPlate(), colour = colour, bunkerId = bunkerId,
        x = x, y = y, z = z, heading = (finite(data.heading) or 0.0) % 360.0,
        status = 'available', createdBy = createdBy,
    }
    row.id = store.scooters.insert(row)
    local entry = { row = row }
    cache[row.id] = entry
    if not spawn(entry) then return false, 'err.spawn_failed' end
    log.info('scooters', 'created #%d %s at %.1f, %.1f, %.1f by %s', row.id, row.plate, x, y, z, tostring(createdBy))
    return view(entry)
end

---Insert + spawn a scooter in a bunker's slot: BunkerOffset rotated by the bunker heading, facing
---away from the slot.
---@param bunkerId integer
---@param colour integer
---@param createdBy string|nil
---@return table|false view
---@return string|nil errKey
---@param customization table|nil extras, validated by scooters.create; nil for the defaults
function scooters.spawnAtBunker(bunkerId, colour, createdBy, customization)
    local b = bunkers.get(bunkerId)
    if not b then return false, 'err.no_bunker' end
    local rad = math.rad(b.heading)
    local ox, oy = CFG.BunkerOffset.x, CFG.BunkerOffset.y
    return scooters.create({
        x = b.x + ox * math.cos(rad) - oy * math.sin(rad),
        y = b.y + ox * math.sin(rad) + oy * math.cos(rad),
        z = b.z + CFG.BunkerOffset.z + CFG.GroundClearance,
        heading = (b.heading + 180.0) % 360.0,
        colour = colour,
        bunkerId = b.id,
        customization = customization,
    }, createdBy)
end

---Despawn + delete.
---@param id integer
---@return boolean ok
---@return string|nil errKey
function scooters.remove(id)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    despawn(entry)
    store.scooters.delete(entry.row.id)
    cache[entry.row.id] = nil
    log.info('scooters', 'deleted #%d %s', entry.row.id, entry.row.plate)
    return true
end

---Recreate the vehicle at its stored position (after it was destroyed, deleted by another script,
---or fell out of the world).
---@param id integer
---@return boolean ok
---@return string|nil errKey
function scooters.respawn(id)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    despawn(entry)
    if not spawn(entry) then return false, 'err.spawn_failed' end
    return true
end

---Repaint, persisted and applied live when the vehicle exists.
---@param id integer
---@param colour integer
---@return boolean ok
---@return string|nil errKey
function scooters.setColour(id, colour)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    local clean = validColour(colour)
    if not clean then return false, 'err.bad_colour' end
    entry.row.colour = clean
    store.scooters.setColour(entry.row.id, clean)
    local e = entry.entity
    if e and DoesEntityExist(e) then
        local paint = CFG.Colours[clean]
        SetVehicleColours(e, paint.primary, paint.primary)
        Entity(e).state:set(STATE_KEY, { id = entry.row.id, colour = clean, customization = entry.row.customization }, true)
    end
    return true
end

---Move a scooter to a spot (the admin's "bring to me"). A docked scooter leaves its slot first; the
---vehicle is placed, unfrozen and its rest position follows. Rented scooters are refused.
---@param id integer
---@param x number
---@param y number
---@param z number
---@param heading number
---@return boolean|false ok
---@return string|nil errKey
function scooters.moveTo(id, x, y, z, heading)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    local r = entry.row
    if r.status == 'rented' then return false, 'err.scooter_rented' end
    if r.stationId then
        stations.release(r.stationId, r.slot)
        r.stationId, r.slot = nil, nil
        store.scooters.setDock(r.id, nil, nil)
        if r.chargeTarget then scooters.setChargeTarget(r.id, nil) end
    end
    if r.status == 'charging' or r.status == 'flat' then
        r.status = 'available'
        store.scooters.setStatus(r.id, 'available')
    end
    entry.flatAt = nil
    r.x, r.y, r.z, r.heading = x + 0.0, y + 0.0, z + 0.0, (heading or 0.0) + 0.0
    store.scooters.setPosition(r.id, r.x, r.y, r.z, r.heading)
    local e = entry.entity
    if e and DoesEntityExist(e) then
        Entity(e).state:set(DOCK_KEY, false, true)
        FreezeEntityPosition(e, false)
        SetEntityCoords(e, r.x, r.y, r.z, false, false, false, false)
        SetEntityHeading(e, r.heading)
    elseif not spawn(entry) then
        return false, 'err.spawn_failed'
    end
    return true
end

---Lock or unlock a scooter's vehicle for everyone.
---@param id integer
---@param locked boolean
---@return boolean|false ok
---@return string|nil errKey
function scooters.setLocked(id, locked)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    local e = entry.entity
    if not e or not DoesEntityExist(e) then return false, 'err.scooter_missing' end
    Entity(e).state:set('doorslockstate', locked and 2 or 1, true)
    SetVehicleDoorsLocked(e, locked and 2 or 1)
    return true
end

---Set a scooter's battery from the admin panel; a docked scooter's slot lens and full flag follow.
---@param id integer
---@param level integer 0..100
---@return boolean|false ok
---@return string|nil errKey
function scooters.setBatteryLevel(id, level)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    level = math.max(0, math.min(100, math.tointeger(math.floor(tonumber(level) or -1)) or -1))
    if level < 0 then return false, 'err.bad_battery' end
    scooters.setBattery(id, level)
    local r = entry.row
    if r.stationId and r.slot then
        stations.setBattery(r.stationId, r.slot, level)
        stations.setFull(r.stationId, r.slot, level >= config.Battery.FullAt)
        if r.chargeTarget and r.chargeTarget <= level then
            scooters.setChargeTarget(id, nil)
            stations.setTarget(r.stationId, r.slot, nil)
        end
    end
    if r.status == 'flat' and level > 0 then
        r.status = 'available'
        entry.flatAt = nil
        store.scooters.setStatus(r.id, 'available')
    end
    return true
end

---Live positions for the map, cheap enough to poll every few seconds.
---@return table[] { id, x, y, z, heading }
function scooters.positions()
    local out = {}
    for _, entry in pairs(cache) do
        local x, y, z, heading = whereIs(entry)
        out[#out + 1] = { id = entry.row.id, x = x, y = y, z = z, heading = heading }
    end
    return out
end

---Persist every live position now. Used on resource stop; write-backs are not awaited there.
function scooters.saveAll()
    syncPositions()
end

---GTA rolls random extras when a vehicle spawns, and this model's extras are its stem poses, so a fresh
---scooter would show every fold pose at once. Any sd_scoot created by anything (the fleet, /car, another
---resource) is flagged here the moment it exists; its owner switches it to the riding stem as soon as
---the model is loaded (client/scoot/bunkers.lua), instead of waiting for the once-a-second check.
AddEventHandler('entityCreated', function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 or GetEntityModel(entity) ~= MODEL then return end
    Entity(entity).state:set('sd_scoot_fresh', GetGameTimer(), true)
end)

---Save every live position and despawn the fleet when this resource stops, so a restart spawns clean.
---@param resource string
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    scooters.saveAll()
    for _, entry in pairs(cache) do despawn(entry) end
end)

---Public API for other resources (and the dev probes). Same functions the admin panel uses.
exports('getScooters', scooters.all)
exports('createScooter', scooters.create)
exports('spawnScooterAtBunker', scooters.spawnAtBunker)
exports('deleteScooter', scooters.remove)
exports('respawnScooter', scooters.respawn)
exports('setScooterColour', scooters.setColour)
exports('getScooterPositions', scooters.positions)
exports('setScooterBattery', scooters.setBatteryLevel)
exports('setScooterLocked', scooters.setLocked)

---Register the module so `require 'server.scoot.scooters'` returns this table.
---@return table
package.preload['server.scoot.scooters'] = function() return scooters end

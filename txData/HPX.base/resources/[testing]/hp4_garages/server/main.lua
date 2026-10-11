local rows, plates, ents = {}, {}, {}
local garages, spots = {}, {}
local spotOwner, spotRes, posRes = {}, {}, {}
local spawning, pending, dirty = {}, {}, {}
local lastProps = {}

HP4 = {
    rows = rows, plates = plates, ents = ents, garages = garages, spots = spots,
    spotOwner = spotOwner, spotRes = spotRes, spawning = spawning, pending = pending, dirty = dirty,
    restoreEnabled = false,
}

local function trim(s)
    return ((tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')))
end
HP4.trim = trim

local function clearanceOf(vtype)
    return Config.clearance[vtype] or Config.defaultClearance
end

local function parseTypes(raw)
    local list, set = {}, {}
    local ok, decoded = pcall(json.decode, raw or '[]')
    if ok and type(decoded) == 'table' then
        for _, t in ipairs(decoded) do
            if not set[t] then set[t] = true list[#list + 1] = t end
        end
    end
    return list, set
end
HP4.parseTypes = parseTypes

local function garageSpots(gid)
    local list = {}
    for _, s in pairs(spots) do
        if s.garage_id == gid then list[#list + 1] = s end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
HP4.garageSpots = garageSpots

local function isClear(x, y, z, vtype, selfId)
    local r = clearanceOf(vtype)
    local p = vector3(x, y, z)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local v = vehicles[i]
        local id = Entity(v).state.hp4id
        if not (selfId and id == selfId) then
            local other = clearanceOf(GetVehicleType(v))
            if #(GetEntityCoords(v) - p) < math.max(r, other) then return false end
        end
    end
    for oid, rp in pairs(posRes) do
        if oid ~= selfId and #(rp.pos - p) < math.max(r, rp.r) then return false end
    end
    return true
end
HP4.isClear = isClear

local function findSpot(gid, vtype, id)
    local g = garages[gid]
    if not g or not g.typeSet[vtype] then return end
    local list = garageSpots(gid)
    for i = 1, #list do
        local s = list[i]
        local own, res = spotOwner[s.id], spotRes[s.id]
        if (not own or own == id) and (not res or res == id) and isClear(s.pos.x, s.pos.y, s.pos.z, vtype, id) then
            spotRes[s.id] = id
            return s
        end
    end
end
HP4.findSpot = findSpot

local function setRowSpot(row, spotId)
    if row.spot_id == spotId then return true end
    if spotId and spotOwner[spotId] and spotOwner[spotId] ~= row.id then return false end
    local gid = spotId and spots[spotId] and spots[spotId].garage_id or row.garage_id
    if not DB.update('UPDATE hp4_vehicles SET spot_id = ?, garage_id = ? WHERE id = ?', { spotId, gid, row.id }) then
        return false
    end
    if row.spot_id then spotOwner[row.spot_id] = nil end
    row.spot_id, row.garage_id = spotId, gid
    if spotId then spotOwner[spotId] = row.id end
    return true
end
HP4.setRowSpot = setRowSpot

local function releaseReservations(id)
    posRes[id] = nil
    for sid, rid in pairs(spotRes) do
        if rid == id then spotRes[sid] = nil end
    end
end

local function adoptWorld()
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        local v = vehicles[i]
        local id = Entity(v).state.hp4id
        if id and rows[id] then
            if ents[id] and ents[id] ~= v and DoesEntityExist(ents[id]) then
                if not spawning[id] then DeleteEntity(v) end
            elseif not ents[id] then
                ents[id] = v
                SetEntityOrphanMode(v, 2)
            end
        elseif not id then
            local pid = plates[trim(GetVehicleNumberPlateText(v))]
            local row = pid and rows[pid]
            if row and row.status == 'active' and not ents[pid] and not spawning[pid] then
                ents[pid] = v
                SetEntityOrphanMode(v, 2)
                Entity(v).state:set('hp4id', pid, true)
            end
        end
    end
end

local function attach(row, ent)
    ents[row.id] = ent
    SetEntityOrphanMode(ent, 2)
    SetVehicleNumberPlateText(ent, row.plate)
    SetVehicleDoorsLocked(ent, row.locked or 0)
    local st = Entity(ent).state
    st:set('hp4id', row.id, true)
    if row.props then st:set('hp4:props', row.props, true) end
end

local function doRestore(row)
    local id, vtype = row.id, row.vtype
    local x, y, z, h = row.x, row.y, row.z, row.h
    local spot = row.spot_id and spots[row.spot_id]
    local r = clearanceOf(vtype)

    local function take(s)
        x, y, z, h = s.pos.x, s.pos.y, s.pos.z, s.h
        posRes[id] = { pos = vector3(x, y, z), r = r }
    end

    if spot then
        if spotRes[spot.id] and spotRes[spot.id] ~= id then return false, 'spot_reserved' end
        spotRes[spot.id] = id
        if isClear(spot.pos.x, spot.pos.y, spot.pos.z, vtype, id) then
            take(spot)
        else
            spotRes[spot.id] = nil
            local alt = findSpot(spot.garage_id, vtype, id)
            if not alt then return false, 'no_spot' end
            take(alt)
            if not setRowSpot(row, alt.id) then return false, 'db' end
        end
    else
        if isClear(x, y, z, vtype, id) then
            posRes[id] = { pos = vector3(x, y, z), r = r }
        else
            local alt = row.garage_id and findSpot(row.garage_id, vtype, id)
            if not alt then return false, 'blocked' end
            take(alt)
            if not setRowSpot(row, alt.id) then return false, 'db' end
        end
    end

    local ent = CreateVehicleServerSetter(row.model, vtype, x + 0.0, y + 0.0, z + 0.0, h + 0.0)
    if not ent or ent == 0 then return false, 'model' end
    ents[id] = ent

    local deadline = GetGameTimer() + Config.spawnTimeout
    while not DoesEntityExist(ent) do
        if GetGameTimer() > deadline then
            ents[id] = nil
            return false, 'timeout'
        end
        Wait(25)
    end

    attach(row, ent)
    FreezeEntityPosition(ent, true)
    Entity(ent).state:set('hp4frozen', true, true)
    row.x, row.y, row.z, row.h = x, y, z, h
    dirty[id] = true
    return true
end

local function tryRestore(row)
    local id = row.id
    if spawning[id] or ents[id] then return true end
    spawning[id] = true
    local ok, res, reason = pcall(doRestore, row)
    spawning[id] = nil
    releaseReservations(id)
    if not ok then
        print(('^1[hp4_garages] restore error for %s: %s^7'):format(row.plate, tostring(res)))
        return false
    end
    if not res and reason == 'model' then
        print(('^3[hp4_garages] invalid model for %s (%s), kept in database^7'):format(row.plate, tostring(row.model)))
    end
    return res == true
end
HP4.tryRestore = tryRestore

local function queue(id, immediate)
    local p = pending[id]
    if not p then pending[id] = { next = 0, tries = 0 } elseif immediate then p.next = 0 end
end
HP4.queue = queue

local function restoreTick()
    adoptWorld()
    local ids = {}
    for id in pairs(pending) do ids[#ids + 1] = id end
    local now, n = os.time(), 0
    for i = 1, #ids do
        local id = ids[i]
        local row, p = rows[id], pending[id]
        if not row or row.status ~= 'active' or ents[id] then
            pending[id] = nil
        elseif p and p.next <= now and n < Config.maxSpawnsPerTick then
            n = n + 1
            if tryRestore(row) then
                pending[id] = nil
            else
                p.tries = p.tries + 1
                p.next = now + math.min(Config.maxBackoff, Config.retryBackoff * p.tries)
            end
        end
    end
end

local function markWrecked(row)
    row.status = 'wrecked'
    if row.spot_id then spotOwner[row.spot_id] = nil row.spot_id = nil end
    dirty[row.id] = true
    local ent = ents[row.id]
    ents[row.id] = nil
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local UPDATE_SQL = 'UPDATE hp4_vehicles SET x = ?, y = ?, z = ?, h = ?, engine = ?, body = ?, locked = ?, props = ?, status = ?, spot_id = ?, garage_id = ? WHERE id = ?'

local function rowParams(row)
    return { row.x, row.y, row.z, row.h, row.engine, row.body, row.locked, row.propsJson, row.status, row.spot_id, row.garage_id, row.id }
end

local function headingDiff(a, b)
    local d = math.abs(a - b) % 360
    return d > 180 and 360 - d or d
end

local function saveTick()
    if not DB.ready then return end
    local changed = {}
    local ids = {}
    for id in pairs(ents) do ids[#ids + 1] = id end

    for i = 1, #ids do
        local id = ids[i]
        local ent, row = ents[id], rows[id]
        if not row then
            ents[id] = nil
        elseif spawning[id] then
            -- spawn in progress
        elseif not DoesEntityExist(ent) then
            ents[id] = nil
            if row.engine <= Config.wreckedEngine then
                markWrecked(row)
                changed[#changed + 1] = row
            elseif row.status == 'active' then
                queue(id)
            end
        elseif not Entity(ent).state.hp4frozen then
            local c = GetEntityCoords(ent)
            local h = GetEntityHeading(ent)
            local eng, body = GetVehicleEngineHealth(ent), GetVehicleBodyHealth(ent)
            local lock = GetVehicleDoorLockStatus(ent)

            local moved = #(c - vector3(row.x, row.y, row.z)) > Config.minMove
                or headingDiff(h, row.h) > Config.minTurn
                or math.abs(eng - row.engine) > Config.minHealth
                or math.abs(body - row.body) > Config.minHealth
                or lock ~= row.locked

            local spotChanged = false
            if row.spot_id then
                local s = spots[row.spot_id]
                if not s or #(c - s.pos) > Config.spotRelease then
                    if s then spotOwner[row.spot_id] = nil end
                    row.spot_id = nil
                    spotChanged = true
                end
            elseif GetPedInVehicleSeat(ent, -1) == 0 then
                local v = GetEntityVelocity(ent)
                if #v < 0.5 then
                    for _, s in pairs(spots) do
                        local g = garages[s.garage_id]
                        if g and g.typeSet[row.vtype] and not spotOwner[s.id] and not spotRes[s.id]
                            and #(c - s.pos) <= Config.spotSnap then
                            spotOwner[s.id] = id
                            row.spot_id, row.garage_id = s.id, s.garage_id
                            spotChanged = true
                            break
                        end
                    end
                end
            end

            if eng <= Config.wreckedEngine then
                row.engine, row.body = eng, body
                markWrecked(row)
                changed[#changed + 1] = row
            elseif moved or spotChanged or dirty[id] then
                row.x, row.y, row.z, row.h = c.x, c.y, c.z, h
                row.engine, row.body, row.locked = eng, body, lock
                dirty[id] = true
            end
        end
    end

    for id in pairs(dirty) do
        if #changed >= Config.maxSavesPerTick then break end
        if rows[id] then changed[#changed + 1] = rows[id] end
    end
    if #changed == 0 then return end

    local seen, unique, queries = {}, {}, {}
    for i = 1, #changed do
        local row = changed[i]
        if not seen[row.id] then
            seen[row.id] = true
            unique[#unique + 1] = row
            queries[#queries + 1] = { query = UPDATE_SQL, values = rowParams(row) }
        end
    end

    if DB.transaction(queries) then
        for i = 1, #unique do dirty[unique[i].id] = nil end
    else
        for i = 1, #unique do
            if DB.update(UPDATE_SQL, rowParams(unique[i])) then dirty[unique[i].id] = nil end
        end
    end
end

local function loadAll()
    local ok, g = DB.query('SELECT id, name, types, x, y, z, radius FROM hp4_garages')
    local ok2, s = DB.query('SELECT id, garage_id, label, x, y, z, h FROM hp4_garage_spots')
    local ok3, v = DB.query('SELECT id, plate, model, label, vtype, garage_id, spot_id, x, y, z, h, engine, body, locked, props, status, owner FROM hp4_vehicles')
    if not (ok and ok2 and ok3) then return false end

    for _, r in ipairs(g or {}) do
        r.types, r.typeSet = parseTypes(r.types)
        garages[r.id] = r
    end
    for _, r in ipairs(s or {}) do
        r.pos = vector3(r.x, r.y, r.z)
        spots[r.id] = r
    end
    for _, r in ipairs(v or {}) do
        r.propsJson = r.props
        if type(r.props) == 'string' then
            local pok, decoded = pcall(json.decode, r.props)
            r.props = pok and type(decoded) == 'table' and decoded or nil
        end
        r.model = tonumber(r.model)
        if r.spot_id and not spots[r.spot_id] then
            r.spot_id = nil
            dirty[r.id] = true
        end
        if r.garage_id and not garages[r.garage_id] then r.garage_id = nil dirty[r.id] = true end
        if r.spot_id then spotOwner[r.spot_id] = r.id end
        rows[r.id] = r
        plates[r.plate] = r.id
    end
    return true
end

---@param ent number
---@param opts? { label?: string, owner?: string, props?: table }
---@return integer|false, string?
local function register(ent, opts)
    opts = opts or {}
    if not DB.ready then return false, 'db' end
    if type(ent) ~= 'number' or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        return false, 'invalid_vehicle'
    end
    local plate = trim(GetVehicleNumberPlateText(ent))
    if plate == '' or #plate > 8 then return false, 'invalid_plate' end
    if plates[plate] then return false, 'registered' end

    local c = GetEntityCoords(ent)
    local row = {
        plate = plate, model = GetEntityModel(ent), label = tostring(opts.label or ''):sub(1, 40),
        vtype = GetVehicleType(ent), x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ent),
        engine = GetVehicleEngineHealth(ent), body = GetVehicleBodyHealth(ent),
        locked = GetVehicleDoorLockStatus(ent), status = 'active', owner = opts.owner,
    }
    if type(opts.props) == 'table' then
        local enc = json.encode(opts.props)
        if enc and #enc <= 30000 and trim(opts.props.plate) == plate then
            row.props, row.propsJson = opts.props, enc
        end
    end

    local ok, id = DB.insert(
        'INSERT INTO hp4_vehicles (plate, model, label, vtype, x, y, z, h, engine, body, locked, props, status, owner) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { row.plate, row.model, row.label, row.vtype, row.x, row.y, row.z, row.h, row.engine, row.body, row.locked, row.propsJson, row.status, row.owner }
    )
    if not ok or not id then return false, 'db' end

    row.id = id
    rows[id] = row
    plates[plate] = id
    ents[id] = ent
    SetEntityOrphanMode(ent, 2)
    Entity(ent).state:set('hp4id', id, true)
    return id
end
HP4.register = register

local function unregister(plate)
    local id = plates[trim(plate)]
    local row = id and rows[id]
    if not row then return false end
    if not DB.update("UPDATE hp4_vehicles SET status = 'released', spot_id = NULL WHERE id = ?", { id }) then return false end
    if row.spot_id then spotOwner[row.spot_id] = nil end
    row.status, row.spot_id = 'released', nil
    local ent = ents[id]
    ents[id], pending[id] = nil, nil
    if ent and DoesEntityExist(ent) then
        Entity(ent).state:set('hp4id', nil, true)
        SetEntityOrphanMode(ent, 0)
    end
    return true
end

exports('Register', register)
exports('Unregister', unregister)

RegisterNetEvent('hp4_garages:props', function(netId, props)
    local src = source
    local now = GetGameTimer()
    if (lastProps[src] or 0) + 1500 > now then return end
    lastProps[src] = now
    if type(netId) ~= 'number' or type(props) ~= 'table' then return end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local id = Entity(ent).state.hp4id
    local row = id and rows[id]
    if not row or ents[id] ~= ent then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > 30.0 then return end
    if trim(props.plate) ~= row.plate then return end

    local enc = json.encode(props)
    if not enc or #enc > 30000 then return end
    row.props, row.propsJson = props, enc
    dirty[id] = true
end)

AddEventHandler('playerDropped', function() lastProps[source] = nil end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pcall(saveTick)
end)

CreateThread(function()
    DB.init()
    while not loadAll() do
        print('^1[hp4_garages] failed to load data, retrying in 10s^7')
        Wait(10000)
    end
    adoptWorld()

    local remaining = Config.restoreDelay * 1000 - GetGameTimer()
    if remaining > 0 then Wait(remaining) end

    adoptWorld()
    for id, row in pairs(rows) do
        if row.status == 'active' and not ents[id] then queue(id) end
    end
    HP4.restoreEnabled = true

    while true do
        local ok, err = pcall(restoreTick)
        if not ok then print('^1[hp4_garages] restore tick: ' .. tostring(err) .. '^7') end
        Wait(Config.restoreTick)
    end
end)

CreateThread(function()
    while not DB.ready do Wait(500) end
    while true do
        Wait(Config.saveInterval)
        local ok, err = pcall(saveTick)
        if not ok then print('^1[hp4_garages] save tick: ' .. tostring(err) .. '^7') end
    end
end)

local H = HP4
local actions = {}

local function canEdit(src)
    return IsPlayerAceAllowed(src, Config.ace)
end

local function placement(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local c = GetEntityCoords(veh)
        return c.x, c.y, c.z, GetEntityHeading(veh), veh
    end
    local c = GetEntityCoords(ped)
    return c.x, c.y, c.z - 0.95, GetEntityHeading(ped)
end

local function cleanName(v)
    v = H.trim(v):sub(1, 40)
    if v == '' then return nil end
    return v
end

local function cleanTypes(list)
    if type(list) ~= 'table' then return nil end
    local valid = {}
    for _, t in ipairs(Config.vehicleTypes) do valid[t] = true end
    local out, seen = {}, {}
    for _, t in ipairs(list) do
        if valid[t] and not seen[t] then seen[t] = true out[#out + 1] = t end
    end
    if #out == 0 then return nil end
    return out
end

local function spacingOk(x, y, z, exceptId)
    local p = vector3(x, y, z)
    for id, s in pairs(H.spots) do
        if id ~= exceptId and #(s.pos - p) < Config.minSpotSpacing then return false end
    end
    return true
end

local function snapshot()
    local out = { types = Config.vehicleTypes, garages = {}, vehicles = {}, restoreEnabled = H.restoreEnabled }
    local ids = {}
    for id in pairs(H.garages) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, gid in ipairs(ids) do
        local g = H.garages[gid]
        local entry = { id = g.id, name = g.name, types = g.types, x = g.x, y = g.y, z = g.z, radius = g.radius, spots = {} }
        for _, s in ipairs(H.garageSpots(gid)) do
            local state, plate = 'free', nil
            local owner = H.spotOwner[s.id]
            if owner then
                state, plate = 'occupied', H.rows[owner] and H.rows[owner].plate
            elseif H.spotRes[s.id] then
                state = 'reserved'
            elseif not H.isClear(s.pos.x, s.pos.y, s.pos.z, 'automobile', nil) then
                state = 'blocked'
            end
            entry.spots[#entry.spots + 1] = { id = s.id, label = s.label, x = s.x, y = s.y, z = s.z, h = s.h, state = state, plate = plate }
        end
        out.garages[#out.garages + 1] = entry
    end

    local vids = {}
    for id in pairs(H.rows) do vids[#vids + 1] = id end
    table.sort(vids)
    for i = 1, math.min(#vids, 500) do
        local r = H.rows[vids[i]]
        local ent = H.ents[r.id]
        out.vehicles[#out.vehicles + 1] = {
            id = r.id, plate = r.plate, label = r.label, vtype = r.vtype, status = r.status,
            garage_id = r.garage_id, spot_id = r.spot_id, live = ent ~= nil and DoesEntityExist(ent),
            pending = H.pending[r.id] ~= nil,
        }
    end
    return out
end

actions.snapshot = function() return true end

actions['garage:create'] = function(src, d)
    local name, types = cleanName(d.name), cleanTypes(d.types)
    if not name or not types then return false, 'invalid_input' end
    local x, y, z = placement(src)
    local radius = math.max(5.0, math.min(500.0, tonumber(d.radius) or 40.0))
    local ok, id = DB.insert('INSERT INTO hp4_garages (name, types, x, y, z, radius) VALUES (?, ?, ?, ?, ?, ?)', { name, json.encode(types), x, y, z, radius })
    if not ok then return false, 'db' end
    local set = {}
    for _, t in ipairs(types) do set[t] = true end
    H.garages[id] = { id = id, name = name, types = types, typeSet = set, x = x, y = y, z = z, radius = radius }
    return true
end

actions['garage:update'] = function(src, d)
    local g = H.garages[tonumber(d.id)]
    if not g then return false, 'not_found' end
    local name, types = cleanName(d.name) or g.name, cleanTypes(d.types) or g.types
    local radius = math.max(5.0, math.min(500.0, tonumber(d.radius) or g.radius))
    local x, y, z = g.x, g.y, g.z
    if d.move then x, y, z = placement(src) end
    if not DB.update('UPDATE hp4_garages SET name = ?, types = ?, x = ?, y = ?, z = ?, radius = ? WHERE id = ?', { name, json.encode(types), x, y, z, radius, g.id }) then
        return false, 'db'
    end
    local set = {}
    for _, t in ipairs(types) do set[t] = true end
    g.name, g.types, g.typeSet, g.x, g.y, g.z, g.radius = name, types, set, x, y, z, radius
    return true
end

actions['garage:delete'] = function(_, d)
    local g = H.garages[tonumber(d.id)]
    if not g then return false, 'not_found' end
    local ok = DB.transaction({
        { query = 'UPDATE hp4_vehicles SET garage_id = NULL, spot_id = NULL WHERE garage_id = ?', values = { g.id } },
        { query = 'DELETE FROM hp4_garage_spots WHERE garage_id = ?', values = { g.id } },
        { query = 'DELETE FROM hp4_garages WHERE id = ?', values = { g.id } },
    })
    if not ok then return false, 'db' end
    for sid, s in pairs(H.spots) do
        if s.garage_id == g.id then
            H.spotOwner[sid], H.spotRes[sid], H.spots[sid] = nil, nil, nil
        end
    end
    for _, r in pairs(H.rows) do
        if r.garage_id == g.id then r.garage_id, r.spot_id = nil, nil end
    end
    H.garages[g.id] = nil
    return true
end

actions['spot:add'] = function(src, d)
    local g = H.garages[tonumber(d.garageId)]
    if not g then return false, 'not_found' end
    local x, y, z, h = placement(src)
    if not spacingOk(x, y, z) then return false, 'spot_too_close' end
    local label = tostring(d.label or ''):sub(1, 40)
    local ok, id = DB.insert('INSERT INTO hp4_garage_spots (garage_id, label, x, y, z, h) VALUES (?, ?, ?, ?, ?, ?)', { g.id, label, x, y, z, h })
    if not ok then return false, 'db' end
    H.spots[id] = { id = id, garage_id = g.id, label = label, x = x, y = y, z = z, h = h, pos = vector3(x, y, z) }
    return true
end

actions['spot:update'] = function(src, d)
    local s = H.spots[tonumber(d.id)]
    if not s then return false, 'not_found' end
    local label = d.label ~= nil and tostring(d.label):sub(1, 40) or s.label
    local x, y, z, h = s.x, s.y, s.z, s.h
    if d.move then
        if H.spotOwner[s.id] or H.spotRes[s.id] then return false, 'spot_occupied' end
        x, y, z, h = placement(src)
        if not spacingOk(x, y, z, s.id) then return false, 'spot_too_close' end
    end
    if not DB.update('UPDATE hp4_garage_spots SET label = ?, x = ?, y = ?, z = ?, h = ? WHERE id = ?', { label, x, y, z, h, s.id }) then
        return false, 'db'
    end
    s.label, s.x, s.y, s.z, s.h, s.pos = label, x, y, z, h, vector3(x, y, z)
    return true
end

actions['spot:delete'] = function(_, d)
    local s = H.spots[tonumber(d.id)]
    if not s then return false, 'not_found' end
    if H.spotRes[s.id] then return false, 'spot_occupied' end
    local ok = DB.transaction({
        { query = 'UPDATE hp4_vehicles SET spot_id = NULL WHERE spot_id = ?', values = { s.id } },
        { query = 'DELETE FROM hp4_garage_spots WHERE id = ?', values = { s.id } },
    })
    if not ok then return false, 'db' end
    local owner = H.spotOwner[s.id]
    if owner and H.rows[owner] then H.rows[owner].spot_id = nil end
    H.spotOwner[s.id], H.spots[s.id] = nil, nil
    return true
end

actions['vehicle:persist'] = function(src, d)
    local ent = NetworkGetEntityFromNetworkId(tonumber(d.netId) or 0)
    if not ent or ent == 0 or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= ent then return false, 'not_in_vehicle' end
    local id, err = H.register(ent, { label = d.label, props = d.props })
    if not id then return false, err end
    return true
end

local function occupied(ent)
    for seat = -1, 6 do
        if GetPedInVehicleSeat(ent, seat) ~= 0 then return true end
    end
    return false
end

actions['vehicle:assign'] = function(_, d)
    local row = H.rows[tonumber(d.vehicleId)]
    local g = H.garages[tonumber(d.garageId)]
    if not row or not g then return false, 'not_found' end
    if row.status ~= 'active' then return false, 'not_active' end
    if not H.restoreEnabled then return false, 'restore_pending' end
    if H.spawning[row.id] then return false, 'busy' end
    if row.spot_id and H.spots[row.spot_id] and H.spots[row.spot_id].garage_id == g.id then return false, 'already_there' end

    local ent = H.ents[row.id]
    if ent and DoesEntityExist(ent) and occupied(ent) then return false, 'occupied' end

    H.spawning[row.id] = true
    local spot = H.findSpot(g.id, row.vtype, row.id)
    if not spot then H.spawning[row.id] = nil return false, 'no_spot' end

    local ok = H.setRowSpot(row, spot.id)
    for sid, rid in pairs(H.spotRes) do
        if rid == row.id then H.spotRes[sid] = nil end
    end
    H.spawning[row.id] = nil
    if not ok then return false, 'db' end

    row.x, row.y, row.z, row.h = spot.x, spot.y, spot.z, spot.h
    H.dirty[row.id] = true
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    H.ents[row.id] = nil
    H.queue(row.id, true)
    return true
end

actions['vehicle:respawn'] = function(_, d)
    local row = H.rows[tonumber(d.vehicleId)]
    if not row then return false, 'not_found' end
    local ent = H.ents[row.id]
    if ent and DoesEntityExist(ent) then return false, 'exists' end
    if row.status == 'wrecked' then
        row.status, row.engine, row.body = 'active', 1000.0, 1000.0
        if row.props then
            row.props.engineHealth, row.props.bodyHealth, row.props.tankHealth = 1000.0, 1000.0, 1000.0
            row.propsJson = json.encode(row.props)
        end
        H.dirty[row.id] = true
    elseif row.status ~= 'active' then
        return false, 'not_active'
    end
    H.queue(row.id, true)
    return true
end

lib.callback.register('hp4_garages:admin', function(src, action, data)
    if not canEdit(src) then return { ok = false, err = 'forbidden' } end
    if not DB.ready then return { ok = false, err = 'db' } end
    local fn = actions[action]
    if not fn then return { ok = false, err = 'unknown' } end
    local ok, res, err = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[hp4_garages] admin action %s failed: %s^7'):format(tostring(action), tostring(res)))
        return { ok = false, err = 'error' }
    end
    if not res then return { ok = false, err = err or 'error', snapshot = snapshot() } end
    return { ok = true, snapshot = snapshot() }
end)

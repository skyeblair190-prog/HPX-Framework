---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'
---@type table Bunker cache (server/scoot/bunkers.lua).
local bunkers = require 'server.scoot.bunkers'
---@type table Scooter fleet (server/scoot/scooters.lua).
local scooters = require 'server.scoot.scooters'
---@type table Framework player helpers (bridge/server/player.lua).
local playerMod = require 'bridge.server.player'
---@type table Framework money helpers (bridge/server/money.lua).
local money = require 'bridge.server.money'
---@type table Vehicle lock + key helpers (bridge/server/keys.lua).
local keys = require 'bridge.server.keys'
---@type table Charging stations: slot bookkeeping and dock poses (server/scoot/stations.lua).
local stations = require 'server.scoot.stations'
---@type table Battery levels and the rent threshold (server/scoot/battery.lua).
local battery = require 'server.scoot.battery'

---@type table Rental tuning (configs/shared/rentals.lua).
local CFG = config.Rentals

---@type table Rentals module; the table returned at end of file.
local extras = require 'shared.extras'
local rentals = {}

---@type table<string, table> Active ride per renter identifier: { id, scooterId, source, startedAt }.
local active = {}
---@type table<integer, string> scooter id -> renter identifier, the reverse index.
local byScooter = {}
---@type table<string, boolean> renter identifier -> true while a bunker is dispensing for them.
local pending = {}

---Started minutes since a ride began, never less than 1.
---@param startedAt integer os.time()
---@return integer
local function minutesSince(startedAt)
    return math.max(1, math.ceil((os.time() - startedAt) / 60))
end

---Apply the idle lock policy to a scooter that nobody is renting.
---@param entry table scooters cache entry
local function lockIdle(entry)
    if CFG.LockIdle and entry.entity then keys.setLocked(entry.entity, true) end
end

---Load and close any ride left open by a restart, then lock the idle fleet. Called once from
---server/main.lua after the scooters spawned.
function rentals.boot()
    local open = store.rentals.open()
    for _, r in ipairs(open) do
        local fare = math.tointeger(tonumber(r.cost) or 0) or 0
        store.rentals.close(r.id, minutesSince(r.startedAt), fare, fare > 0 and 1 or 0, { endedBy = 'restart' })
    end
    if #open > 0 then log.warn('rentals', 'closed %d ride(s) left open by a restart', #open) end
    for _, s in ipairs(scooters.all()) do
        local entry = scooters.get(s.id)
        if entry then
            if entry.row.status == 'flat' then
                entry.flatAt = os.time()
            elseif entry.row.status ~= 'charging' then
                entry.row.status = 'available'
            end
            local home = entry.row.bunkerId and bunkers.get(entry.row.bunkerId) or nil
            local dispensed = type(entry.row.createdBy) == 'string' and entry.row.createdBy:sub(1, 9) == 'dispense:'
            if entry.row.status ~= 'charging' and dispensed and home and #(vector3(s.x, s.y, s.z) - vector3(home.x, home.y, home.z)) <= CFG.DockDistance then
                scooters.remove(entry.row.id)
                bunkers.adjustStock(home.id, 1)
                log.warn('rentals', 'docked %s back into %s: its ride ended with a restart', s.plate, home.name)
            else
                lockIdle(entry)
            end
        end
    end
    scooters.onSpawn(function(entry)
        if not byScooter[entry.row.id] then lockIdle(entry) end
    end)
end

---Where a ride is happening: the scooter's live position, else the renter's ped, else nothing.
---@param entry table|nil scooters cache entry
---@param source number|nil
---@return table|nil { x, y }
local function ridePoint(entry, source)
    if entry and entry.entity and DoesEntityExist(entry.entity) then
        local c = GetEntityCoords(entry.entity)
        return { x = c.x, y = c.y }
    end
    local ped = source and GetPlayerPed(source)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        return { x = c.x, y = c.y }
    end
    return nil
end

---Close detail for store.rentals.close: end point and why it ended.
---@param entry table|nil
---@param source number|nil
---@param endedBy string
---@return table
local function closeDetail(entry, source, endedBy)
    local at = ridePoint(entry, source) or {}
    return { x = at.x, y = at.y, endedBy = endedBy }
end

---Distance between a player and a scooter's live position.
---@param source number
---@param entry table
---@return number
local function distanceTo(source, entry)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not entry.entity or not DoesEntityExist(entry.entity) then return math.huge end
    return #(GetEntityCoords(ped) - GetEntityCoords(entry.entity))
end

---The player's current ride, if any, as the app shows it.
---@param source number
---@return table|nil
function rentals.current(source)
    local id = playerMod.getIdentifier(source)
    local ride = id and active[id]
    if not ride then return nil end
    local entry = scooters.get(ride.scooterId)
    local minutes = minutesSince(ride.startedAt)
    return {
        id = ride.id,
        scooterId = ride.scooterId,
        battery = entry and battery.level(entry) or nil,
        plate = entry and entry.row.plate or '?',
        colour = entry and entry.row.colour or 1,
        customization = entry and entry.row.customization or extras.decode(nil),
        extraFee = select(2, extras.normalise(entry and entry.row.customization)),
        startedAt = ride.startedAt,
        minutes = minutes,
        cost = ride.fare,
    }
end

---@type fun(source: number, id: string, entry: table): table Shared tail of rent() and rentAtBunker(); defined below.
local startRide

---Start a ride: the scooter must be free (parked or charging), charged enough, close, and the
---unlock fee must clear.
---@param source number
---@param scooterId integer
---@param account string|nil 'bank' | 'cash'; defaults to Rentals.Account
---@return table|false ride
---@return string|nil errKey
function rentals.rent(source, scooterId, account)
    local id = playerMod.getIdentifier(source)
    if not id then return false, 'err.no_framework' end
    if active[id] then return false, 'err.already_riding' end
    local entry = scooters.get(scooterId)
    if not entry or not entry.entity or not DoesEntityExist(entry.entity) then return false, 'err.no_scooter' end
    if byScooter[entry.row.id] or (entry.row.status ~= 'available' and entry.row.status ~= 'charging') then return false, 'err.scooter_taken' end
    if not battery.canRent(entry) then return false, 'err.needs_charge' end
    if distanceTo(source, entry) > CFG.RentDistance then return false, 'err.too_far' end
    local _, extraFee = extras.normalise(entry.row.customization)
    if not money.remove(source, account or CFG.Account, CFG.UnlockFee + extraFee, 'scoot-unlock') then return false, 'err.no_money' end
    return startRide(source, id, entry)
end

---The account a screen purchase may be paid from, or nil when the choice is not offered.
---@param account any
---@return string|nil
local function screenAccount(account)
    local methods = config.Stations.Screen.Payment and config.Stations.Screen.Payment.Methods or { 'bank' }
    for _, m in ipairs(methods) do
        if m == account then return m end
    end
    return nil
end

---Everyone whose ped is within radius of a point, as server ids.
---@param x number
---@param y number
---@param z number
---@param radius number
---@return integer[]
local function playersNear(x, y, z, radius)
    local out = {}
    local at = vector3(x, y, z)
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped and ped ~= 0 and #(GetEntityCoords(ped) - at) <= radius then out[#out + 1] = tonumber(id) end
    end
    return out
end

---Open a ride on a scooter the caller already stands next to (or that a bunker just produced).
---Shared tail of rent() and rentAtBunker(). A scooter taken out of a charging slot frees it.
---@param source number
---@param id string renter identifier
---@param entry table scooters cache entry
---@return table current ride
function startRide(source, id, entry)
    if entry.row.stationId then
        stations.release(entry.row.stationId, entry.row.slot)
        scooters.undock(entry.row.id)
    end
    local startedAt = os.time()
    local at = ridePoint(entry, source) or {}
    local renterName = playerMod.getName(source)
    local fare = CFG.UnlockFee + (select(2, extras.normalise(entry.row.customization)) or 0)
    local rideId = store.rentals.insert({
        scooterId = entry.row.id, plate = entry.row.plate, bunkerId = entry.row.bunkerId,
        renter = id, renterName = renterName, startedAt = startedAt, fare = fare, x = at.x, y = at.y,
    })
    active[id] = { id = rideId, scooterId = entry.row.id, source = source, startedAt = startedAt, renterName = renterName, plate = entry.row.plate, fare = fare }
    byScooter[entry.row.id] = id
    entry.row.status = 'rented'
    store.scooters.setStatus(entry.row.id, 'rented')
    keys.setLocked(entry.entity, false)
    keys.give(source, entry.entity)
    log.info('rentals', '%s started ride #%d on %s', playerMod.getName(source), rideId, entry.row.plate)
    local current = rentals.current(source)
    TriggerEvent('sd_scoot:rideUpdated', source, 'started', current)
    TriggerClientEvent('sd_scoot:client:rideUpdated', source, 'started', current)
    return current
end

---Rent at a station: the bunker rises, dispenses a scooter and the ride starts on it. The fee is
---taken up front; the vehicle only exists once the animation has unfolded it, so the ride opens on
---a timer rather than in this call. Every client near the bunker plays the same cycle.
---@param source number
---@param bunkerId integer
---@return table|false dispense { bunkerId, colour, spawnAt }
---@return string|nil errKey
function rentals.rentAtBunker(source, bunkerId, requestedColour, requestedCustomization)
    local customization, extraFee = extras.normalise(requestedCustomization)
    if not customization then return false, extraFee end
    if requestedColour ~= nil and (type(requestedColour) ~= 'number' or requestedColour % 1 ~= 0 or not config.Scooters.Colours[requestedColour]) then return false, 'err.bad_colour' end
    local id = playerMod.getIdentifier(source)
    if not id then return false, 'err.no_framework' end
    if active[id] or pending[id] then return false, 'err.already_riding' end
    local b = bunkers.get(bunkerId)
    if not b or not b.enabled then return false, 'err.no_bunker' end
    if b.busy then return false, 'err.station_busy' end
    if (b.stock or 0) < 1 then return false, 'err.no_stock' end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(b.x, b.y, b.z)) > CFG.StationDistance then return false, 'err.too_far_station' end
    if not money.remove(source, CFG.Account, CFG.UnlockFee + extraFee, 'scoot-unlock') then return false, 'err.no_money' end

    local D = config.Bunkers.Dispense
    local colour = requestedColour or D.Colour or math.random(1, #config.Scooters.Colours)
    pending[id] = { bunkerId = b.id, colour = colour, customization = customization, extraFee = extraFee, readyAt = os.time() + math.ceil(D.SpawnAt / 1000) }
    bunkers.setBusy(b.id, true)
    bunkers.adjustStock(b.id, -1)
    for _, target in ipairs(playersNear(b.x, b.y, b.z, config.Bunkers.DispenseRadius)) do
        TriggerClientEvent('sd_scoot:client:dispense', target, b.id, colour, customization)
    end
    log.info('rentals', '%s ordered a scooter at bunker #%d %s', playerMod.getName(source), b.id, b.name)

    local rad = math.rad(b.heading)
    local rest = {
        x = b.x + D.ScooterClear * math.cos(rad),
        y = b.y + D.ScooterClear * math.sin(rad),
        z = b.z + config.Scooters.GroundClearance,
        heading = (b.heading + D.VehicleHeadingOffset) % 360.0,
    }
    local entry = nil
    SetTimeout(D.VehicleAt, function()
        local view, err = scooters.create({
            x = rest.x, y = rest.y, z = rest.z - (D.Vehicle and D.Vehicle.HiddenDepth or 3.0), heading = rest.heading,
            colour = colour, customization = customization,
            bunkerId = b.id,
        }, 'dispense:' .. id)
        if not view then
            log.error('rentals', 'dispense at bunker #%d failed: %s', b.id, tostring(err))
            return
        end
        entry = scooters.get(view.id)
        if entry and entry.entity then Entity(entry.entity).state:set('sd_scoot_dispense', { bunkerId = b.id }, true) end
    end)
    SetTimeout(D.SpawnAt, function()
        pending[id] = nil
        if not entry then
            bunkers.adjustStock(b.id, 1)
            money.add(source, CFG.Account, CFG.UnlockFee + extraFee, 'scoot-refund')
            return
        end
        scooters.setRestPosition(entry.row.id, rest.x, rest.y, rest.z, rest.heading)
        if entry.entity and DoesEntityExist(entry.entity) then Entity(entry.entity).state:set('sd_scoot_dispense', false, true) end
        if GetPlayerPed(source) == 0 or playerMod.getIdentifier(source) ~= id then
            lockIdle(entry)
            return
        end
        startRide(source, id, entry)
    end)
    SetTimeout(D.TotalMs, function()
        bunkers.setBusy(b.id, false)
        local live = entry and entry.entity
        if not live or not DoesEntityExist(live) then return end
        local at = GetEntityCoords(live)
        if at.z >= rest.z - 1.0 then return end
        SetEntityCoords(live, rest.x, rest.y, rest.z, false, false, false, false)
        SetEntityHeading(live, rest.heading)
        log.warn('rentals', 'bunker #%d: no client lifted the scooter out of hiding, placed it at the bay', b.id)
    end)
    return { bunkerId = b.id, colour = colour, customization = customization, extraFee = extraFee, spawnAt = D.SpawnAt }
end

---The enabled bunker within DockDistance of a player, or nil.
---@param source number
---@return table|nil
local function dockableBunker(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local pc = GetEntityCoords(ped)
    local best, bestD = nil, CFG.DockDistance
    for _, b in ipairs(bunkers.all()) do
        if b.enabled then
            local d = #(pc - vector3(b.x, b.y, b.z))
            if d <= bestD then best, bestD = b, d end
        end
    end
    return best
end

---End the caller's ride. The fare was paid once when the scooter was unlocked, so nothing is charged here;
---the ride closes with that fare and the scooter is docked, returned to a bunker or parked.
---@param source number
---@param endedBy string|nil why it ended, stored with the ride: 'rider' (default) | 'admin' | 'timeout'
---@return table|false receipt { plate, minutes, cost, paid }
---@return string|nil errKey
function rentals.finish(source, endedBy)
    local id = playerMod.getIdentifier(source)
    local ride = id and active[id]
    if not ride then return false, 'err.not_riding' end
    local entry = scooters.get(ride.scooterId)
    local minutes = minutesSince(ride.startedAt)
    local cost = ride.fare
    store.rentals.close(ride.id, minutes, cost, 1, closeDetail(entry, source, endedBy or 'rider'))
    active[id] = nil
    byScooter[ride.scooterId] = nil
    local plate = entry and entry.row.plate or '?'
    local ped = GetPlayerPed(source)
    local pc = ped and ped ~= 0 and GetEntityCoords(ped) or nil
    local station, slot = nil, nil
    if entry and pc then
        station = stations.nearest(pc.x, pc.y, pc.z, CFG.DockDistance, true)
        if station then
            local vc = entry.entity and DoesEntityExist(entry.entity) and GetEntityCoords(entry.entity) or pc
            slot = stations.nearestFreeSlot(station, vc.x, vc.y, vc.z) or stations.freeSlot(station)
        end
    end
    local dock = nil
    if entry and not station then dock = dockableBunker(source) end
    if entry and station and slot then
        if entry.entity and DoesEntityExist(entry.entity) then keys.remove(source, entry.entity) end
        scooters.dock(entry.row.id, station.id, slot)
        stations.occupy(station.id, slot, entry.row.id, battery.level(entry) >= config.Battery.FullAt, { plate = entry.row.plate, colour = entry.row.colour, battery = battery.level(entry) })
        lockIdle(entry)
        dock = station
    elseif entry and dock then
        if entry.entity and DoesEntityExist(entry.entity) then keys.remove(source, entry.entity) end
        scooters.remove(entry.row.id)
        bunkers.adjustStock(dock.id, 1)
    elseif entry then
        entry.row.status = 'available'
        store.scooters.setStatus(entry.row.id, 'available')
        if entry.entity and DoesEntityExist(entry.entity) then
            keys.remove(source, entry.entity)
            lockIdle(entry)
        end
    end
    log.info('rentals', '%s ended ride #%d after %d min (fare %s%d)%s', playerMod.getName(source), ride.id, minutes, CFG.Currency, cost, dock and (', docked at ' .. dock.name) or '')
    local receipt = { plate = plate, minutes = minutes, cost = cost, paid = true, docked = dock and dock.name or nil, charging = station ~= nil, battery = entry and battery.level(entry) or nil }
    TriggerEvent('sd_scoot:rideUpdated', source, 'ended', receipt)
    TriggerClientEvent('sd_scoot:client:rideUpdated', source, 'ended', receipt)
    return receipt
end

---A ride drained its scooter to zero: the ride ends and is billed as usual, the scooter locks
---where it stands as `flat` and waits for the fleet to collect it. The rider hears why.
battery.onFlat(function(entry)
    local id = byScooter[entry.row.id]
    local ride = id and active[id]
    if not ride then return end
    local source = ride.source
    local minutes = minutesSince(ride.startedAt)
    local cost = ride.fare
    local online = source and GetPlayerPed(source) ~= 0 and playerMod.getIdentifier(source) == id
    store.rentals.close(ride.id, minutes, cost, 1, closeDetail(entry, nil, 'flat'))
    active[id] = nil
    byScooter[entry.row.id] = nil
    entry.row.status = 'flat'
    entry.flatAt = os.time()
    store.scooters.setStatus(entry.row.id, 'flat')
    if entry.entity and DoesEntityExist(entry.entity) then
        if online then keys.remove(source, entry.entity) end
        lockIdle(entry)
    end
    log.info('rentals', 'ride #%d on %s ended flat after %d min (fare %s%d)', ride.id, entry.row.plate, minutes, CFG.Currency, cost)
    if not online then return end
    local receipt = { plate = entry.row.plate, minutes = minutes, cost = cost, paid = true, flat = true, battery = 0 }
    TriggerEvent('sd_scoot:rideUpdated', source, 'ended', receipt)
    TriggerClientEvent('sd_scoot:client:rideUpdated', source, 'ended', receipt)
    TriggerClientEvent('ox_lib:notify', source, { title = locale('notify.title'), description = locale('notify.flat', entry.row.plate), type = 'warning' })
end)

---Free the scooter when a renter drops without ending the ride; the ride closes with the fare they paid.
---@param source number
---@param endedBy string|nil 'dropped' (default) | 'timeout' | 'admin'
function rentals.dropped(source, endedBy)
    for id, ride in pairs(active) do
        if ride.source == source then
            local minutes = minutesSince(ride.startedAt)
            local entry = scooters.get(ride.scooterId)
            store.rentals.close(ride.id, minutes, ride.fare, 1, closeDetail(entry, nil, endedBy or 'dropped'))
            active[id] = nil
            byScooter[ride.scooterId] = nil
            if entry then
                entry.row.status = 'available'
                store.scooters.setStatus(entry.row.id, 'available')
                lockIdle(entry)
            end
            log.warn('rentals', 'ride #%d closed: renter %s disconnected', ride.id, id)
        end
    end
end

---Cut a nearest-first list down to ListLimit entries, in place.
---@param list table[]
local function trim(list)
    local limit = math.tointeger(CFG.ListLimit) or 50
    for i = #list, limit + 1, -1 do list[i] = nil end
end

---What the app shows: loose scooters inside NearbyRadius, and every enabled bunker and charging
---station nearest first (the Stations tab is a directory, so those are not distance-capped), plus
---the player's own coordinates, prices and the active ride.
---@param source number
---@return table
function rentals.nearby(source)
    local ped = GetPlayerPed(source)
    local pc = ped and ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local out = { player = { x = pc.x, y = pc.y, z = pc.z, heading = ped and ped ~= 0 and GetEntityHeading(ped) or 0.0 }, scooters = {}, bunkers = {}, stations = {}, ride = rentals.current(source) }
    local B = config.Battery
    for _, s in ipairs(scooters.all()) do
        local d = #(pc - vector3(s.x, s.y, s.z))
        if d <= CFG.NearbyRadius and s.exists then
            local available = (s.status == 'available' or s.status == 'charging') and not byScooter[s.id]
            out.scooters[#out.scooters + 1] = {
                id = s.id, plate = s.plate, colour = s.colour, customization = s.customization, extraFee = select(2, extras.normalise(s.customization)),
                x = s.x, y = s.y, z = s.z, distance = d, available = available, bunkerId = s.bunkerId,
                battery = B.Enabled and s.battery or 100, rentable = available and (not B.Enabled or s.battery >= B.MinToRent),
                charging = s.status == 'charging' and (not battery.isPaid() or s.chargeTarget ~= nil), flat = s.status == 'flat', stationId = s.stationId,
            }
        end
    end
    for _, st in ipairs(stations.all()) do
        if st.enabled then
            local d = #(pc - vector3(st.x, st.y, st.z))
            out.stations[#out.stations + 1] = { id = st.id, name = st.name, x = st.x, y = st.y, z = st.z, distance = d, slots = #st.slots, free = #st.slots - st.occupied, occupied = st.occupied }
        end
    end
    table.sort(out.stations, function(a, b) return a.distance < b.distance end)
    trim(out.stations)
    out.battery = { enabled = B.Enabled == true, minToRent = B.MinToRent, fullAt = B.FullAt }
    for _, b in ipairs(bunkers.all()) do
        if b.enabled then
            local d = #(pc - vector3(b.x, b.y, b.z))
            out.bunkers[#out.bunkers + 1] = { id = b.id, name = b.name, x = b.x, y = b.y, z = b.z, distance = d, stock = b.stock or 0, busy = b.busy == true }
        end
    end
    table.sort(out.scooters, function(a, b) return a.distance < b.distance end)
    table.sort(out.bunkers, function(a, b) return a.distance < b.distance end)
    trim(out.bunkers)
    out.colours = {}
    for colourId, colour in ipairs(config.Scooters.Colours) do
        out.colours[#out.colours + 1] = { id = colourId, name = colour.name, hex = colour.hex }
    end
    local renter = playerMod.getIdentifier(source)
    out.dispense = renter and pending[renter] or nil
    out.extrasCatalog = extras.catalog
    out.canChooseColour = true
    out.pricing = { unlock = CFG.UnlockFee, currency = CFG.Currency, rentDistance = CFG.RentDistance, stationDistance = CFG.StationDistance, dockDistance = CFG.DockDistance, refreshMs = CFG.RefreshMs }
    return out
end

---The caller's last rides, newest first.
---@param source number
---@return table[]
function rentals.history(source)
    local id = playerMod.getIdentifier(source)
    if not id then return {} end
    return store.rentals.history(id, 15)
end

---Dock the scooter a player rode up to a station. Rented by them: the ride ends and docks like the
---app's End ride. Idle or flat fleet scooter: parked straight into a free slot. Not a fleet
---scooter at all: adopted into the fleet first. Rented by someone else: refused.
---@param src integer
---@param netId integer network id of the vehicle
---@return table|false result { docked, battery, receipt? }
---@return string|nil errKey
function rentals.dockVehicle(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'err.no_scooter' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'err.no_scooter' end
    local pc = GetEntityCoords(ped)
    if #(pc - GetEntityCoords(veh)) > 8.0 then return false, 'err.too_far' end
    local station = stations.nearest(pc.x, pc.y, pc.z, CFG.DockDistance, true)
    if not station then return false, 'err.no_dock' end
    local id = playerMod.getIdentifier(src)
    local entry = scooters.byEntity(veh)
    if entry then
        local renter = byScooter[entry.row.id]
        if renter and renter ~= id then return false, 'err.scooter_taken' end
        if renter then
            local receipt, err = rentals.finish(src)
            if not receipt then return false, err end
            return { docked = receipt.docked, battery = receipt.battery, receipt = receipt }
        end
        if entry.row.status == 'charging' then return false, 'err.already_docked' end
        if entry.row.status == 'rented' then return false, 'err.scooter_taken' end
    else
        local adopted, err = scooters.adopt(veh, 'adopt:' .. tostring(id or src))
        if not adopted then return false, err end
        entry = adopted
    end
    entry.flatAt = nil
    local vc = GetEntityCoords(veh)
    local slot = stations.nearestFreeSlot(station, vc.x, vc.y, vc.z) or stations.freeSlot(station)
    scooters.dock(entry.row.id, station.id, slot)
    stations.occupy(station.id, slot, entry.row.id, battery.level(entry) >= config.Battery.FullAt, { plate = entry.row.plate, colour = entry.row.colour, battery = battery.level(entry) })
    lockIdle(entry)
    log.info('rentals', '%s docked %s at %s slot %d', playerMod.getName(src), entry.row.plate, station.name, slot)
    return { docked = station.name, battery = battery.level(entry) }
end

---Unlock a scooter from a station's own screen: the caller stands at the pillar and picks a dock.
---The ride, fee, battery and distance rules are the app's; the station only resolves the slot.
---@param src integer
---@param stationId integer
---@param slot integer
---@param account string|nil 'bank' | 'cash' as offered on the screen; defaults to Rentals.Account
---@return table|false ride
---@return string|nil errKey
function rentals.unlockAtStation(src, stationId, slot, account)
    if account ~= nil and not screenAccount(account) then return false, 'err.bad_payment' end
    local station = stations.get(stationId)
    if not station or not station.enabled then return false, 'err.no_station' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(station.x, station.y, station.z)) > CFG.RentDistance then return false, 'err.too_far' end
    local occupant = station.slots and station.slots[tonumber(slot) or -1]
    if not occupant then return false, 'err.dock_empty' end
    return rentals.rent(src, occupant.scooterId, account)
end

---Buy a charge for the scooter in a dock, from the station screen: the caller stands at the
---pillar, picks a target percent, and the bill is taken from the configured account. Changing an
---active target is allowed as long as it goes up; only the added percent is billed.
---@param src integer
---@param stationId integer
---@param slot integer
---@param target integer
---@param account string|nil 'bank' | 'cash' as offered on the screen; defaults to Paid.Account
---@return table|false result { plate, level, target, adds, minutes, cost }
---@return string|nil errKey
function rentals.chargeAtStation(src, stationId, slot, target, account)
    if not battery.isPaid() then return false, 'err.charge_free' end
    if account ~= nil and not screenAccount(account) then return false, 'err.bad_payment' end
    local station = stations.get(stationId)
    if not station or not station.enabled then return false, 'err.no_station' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(station.x, station.y, station.z)) > CFG.RentDistance then return false, 'err.too_far' end
    local occupant = station.slots and station.slots[tonumber(slot) or -1]
    if not occupant then return false, 'err.dock_empty' end
    local entry = scooters.get(occupant.scooterId)
    if not entry or entry.row.status ~= 'charging' then return false, 'err.dock_empty' end
    local quote, err = battery.quote(entry, target)
    if not quote then return false, err end
    local paid = config.Battery.Paid
    local already = entry.row.chargeTarget
    if already and quote.target <= already then return false, 'err.already_charging' end
    if already then
        local extra = quote.target - already
        quote.cost = math.max(tonumber(paid.MinimumFee) or 0, math.ceil(extra * (tonumber(paid.PricePerPercent) or 0)))
    end
    if not money.remove(src, account or paid.Account or CFG.Account, quote.cost, 'scoot-charge') then return false, 'err.no_money' end
    scooters.setChargeTarget(entry.row.id, quote.target)
    stations.setTarget(station.id, slot, quote.target)
    log.info('rentals', '%s bought a charge to %d%% for %s at %s slot %d (%s%d)', playerMod.getName(src), quote.target, entry.row.plate, station.name, slot, CFG.Currency, quote.cost)
    quote.plate = entry.row.plate
    return quote
end

---Stop a running charge from the station screen. The percent not yet delivered is refunded at the
---purchase rate (whole currency, rounded down) when Paid.RefundOnStop allows it.
---@param src integer
---@param stationId integer
---@param slot integer
---@param account string|nil account the refund goes to; defaults to Paid.Account
---@return table|false result { plate, level, refund }
---@return string|nil errKey
function rentals.stopChargeAtStation(src, stationId, slot, account)
    if not battery.isPaid() then return false, 'err.charge_free' end
    if account ~= nil and not screenAccount(account) then return false, 'err.bad_payment' end
    local station = stations.get(stationId)
    if not station or not station.enabled then return false, 'err.no_station' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(station.x, station.y, station.z)) > CFG.RentDistance then return false, 'err.too_far' end
    local occupant = station.slots and station.slots[tonumber(slot) or -1]
    if not occupant then return false, 'err.dock_empty' end
    local entry = scooters.get(occupant.scooterId)
    if not entry or not entry.row.chargeTarget then return false, 'err.not_charging' end
    local paid = config.Battery.Paid
    local level = battery.level(entry)
    local remaining = math.max(0, entry.row.chargeTarget - level)
    local refund = paid.RefundOnStop ~= false and math.floor(remaining * (tonumber(paid.PricePerPercent) or 0)) or 0
    scooters.setChargeTarget(entry.row.id, nil)
    stations.setTarget(station.id, slot, nil)
    if refund > 0 then money.add(src, account or paid.Account or CFG.Account, refund, 'scoot-charge-refund') end
    log.info('rentals', '%s stopped charging %s at %s slot %d at %d%% (refund %s%d)', playerMod.getName(src), entry.row.plate, station.name, slot, level, CFG.Currency, refund)
    return { plate = entry.row.plate, level = level, refund = refund }
end

---Station screen: stop a paid charge in a dock and refund the unused percent.
---@param src integer
---@param stationId integer
---@param slot integer
---@param account string|nil 'bank' | 'cash'
---@return table reply { success, data = { plate, level, refund } } or a localised failure
lib.callback.register('sd_scoot:server:stations:stopCharge', function(src, stationId, slot, account)
    if not CFG.Enabled then return { success = false, message = locale('err.app_disabled') } end
    local okay, result, err = pcall(rentals.stopChargeAtStation, src, tonumber(stationId) or -1, tonumber(slot) or -1, account)
    if not okay then
        log.error('rentals', 'screen stop charge failed for %s: %s', tostring(src), tostring(result))
        return { success = false, message = locale('ui.toast.failed') }
    end
    if not result then return { success = false, message = locale(err or 'ui.toast.failed') } end
    return { success = true, data = result }
end)

---Station screen: buy a charge up to a target percent for the scooter in a dock.
---@param src integer
---@param stationId integer
---@param slot integer
---@param target integer
---@param account string|nil 'bank' | 'cash'
---@return table reply { success, data = charge result } or a localised failure
lib.callback.register('sd_scoot:server:stations:charge', function(src, stationId, slot, target, account)
    if not CFG.Enabled then return { success = false, message = locale('err.app_disabled') } end
    local okay, result, err = pcall(rentals.chargeAtStation, src, tonumber(stationId) or -1, tonumber(slot) or -1, target, account)
    if not okay then
        log.error('rentals', 'screen charge failed for %s: %s', tostring(src), tostring(result))
        return { success = false, message = locale('ui.toast.failed') }
    end
    if not result then return { success = false, message = locale(err or 'ui.toast.failed') } end
    return { success = true, data = result }
end)

---Station screen: unlock the scooter in a dock and start a ride on it.
---@param src integer
---@param stationId integer
---@param slot integer
---@param account string|nil 'bank' | 'cash'
---@return table reply { success, data = { ride } } or a localised failure
lib.callback.register('sd_scoot:server:stations:unlock', function(src, stationId, slot, account)
    if not CFG.Enabled then return { success = false, message = locale('err.app_disabled') } end
    local okay, result, err = pcall(rentals.unlockAtStation, src, tonumber(stationId) or -1, slot, account)
    if not okay then
        log.error('rentals', 'screen unlock failed for %s: %s', tostring(src), tostring(result))
        return { success = false, message = locale('ui.toast.failed') }
    end
    if not result then return { success = false, message = locale(err or 'ui.toast.failed') } end
    return { success = true, data = { ride = result } }
end)

---Dock the scooter a player rode up to a station: ends their ride, parks an idle one or adopts it.
---@param src integer
---@param netId integer network id of the vehicle
---@return table reply { success, data = { docked, battery, receipt? } } or a localised failure
lib.callback.register('sd_scoot:server:stations:dock', function(src, netId)
    if not CFG.Enabled then return { success = false, message = locale('err.app_disabled') } end
    local okay, result, err = pcall(rentals.dockVehicle, src, netId)
    if not okay then
        log.error('rentals', 'dock failed for %s: %s', tostring(src), tostring(result))
        return { success = false, message = locale('ui.toast.failed') }
    end
    if not result then return { success = false, message = locale(err or 'ui.toast.failed') } end
    return { success = true, data = result }
end)

---Close and bill the ride of a player who disconnects mid-ride.
AddEventHandler('playerDropped', function()
    rentals.dropped(source)
end)

---Rides forgotten on a scooter are closed after MaxRideMinutes so the fleet never leaks.
CreateThread(function()
    while true do
        Wait(60000)
        for id, ride in pairs(active) do
            if minutesSince(ride.startedAt) >= CFG.MaxRideMinutes then
                local src = ride.source
                if src and GetPlayerPed(src) ~= 0 then rentals.finish(src, 'timeout') else rentals.dropped(src, 'timeout') end
            end
        end
    end
end)

---Every ride in progress, as the admin panel shows it.
---@return table[] { id, renter, renterName, source, online, scooterId, plate, startedAt, minutes, cost, battery, x, y }
function rentals.active()
    local out = {}
    for id, ride in pairs(active) do
        local entry = scooters.get(ride.scooterId)
        local minutes = minutesSince(ride.startedAt)
        local at = ridePoint(entry, ride.source) or {}
        out[#out + 1] = {
            id = ride.id, renter = id, renterName = ride.renterName or id, source = ride.source,
            online = ride.source ~= nil and GetPlayerPed(ride.source) ~= 0,
            scooterId = ride.scooterId, plate = entry and entry.row.plate or ride.plate or '?',
            startedAt = ride.startedAt, minutes = minutes, cost = ride.fare,
            battery = entry and battery.level(entry) or nil, x = at.x, y = at.y,
        }
    end
    table.sort(out, function(a, b) return a.startedAt < b.startedAt end)
    return out
end

---Online renters and the scooter each one has.
---@return table<integer, integer> server id -> scooter id
function rentals.riders()
    local out = {}
    for _, ride in pairs(active) do
        if ride.source and GetPlayerPed(ride.source) ~= 0 then out[ride.source] = ride.scooterId end
    end
    return out
end

---The renter identifier riding a scooter, or nil.
---@param scooterId integer
---@return string|nil
function rentals.renterOf(scooterId)
    return byScooter[scooterId]
end

---End a ride from the admin panel. An online rider is docked exactly like ending it
---themselves (and told why); an offline one is closed the way a disconnect is.
---@param rideId integer
---@return table|false result { plate, renterName }
---@return string|nil errKey
function rentals.forceEnd(rideId)
    rideId = tonumber(rideId)
    for id, ride in pairs(active) do
        if ride.id == rideId then
            local plate = ride.plate
            local name = ride.renterName or id
            local src = ride.source
            if src and GetPlayerPed(src) ~= 0 and playerMod.getIdentifier(src) == id then
                rentals.finish(src, 'admin')
                TriggerClientEvent('ox_lib:notify', src, { title = locale('notify.title'), description = locale('notify.ride_ended_by_admin'), type = 'warning' })
            else
                rentals.dropped(src, 'admin')
            end
            return { plate = plate, renterName = name }
        end
    end
    return false, 'err.ride_not_active'
end

---The server id of an online player by framework identifier, or nil.
---@param identifier string
---@return integer|nil
local function onlineSource(identifier)
    for _, sid in ipairs(GetPlayers()) do
        local n = tonumber(sid)
        if n and playerMod.getIdentifier(n) == identifier then return n end
    end
    return nil
end

---Give a paid ride's money back to its renter (the part not refunded yet). The renter has to be
---online: offline balances belong to the framework and are not touched from here.
---@param rideId integer
---@return table|false result { amount, renterName, plate }
---@return string|nil errKey
function rentals.refund(rideId)
    local ride = store.rentals.get(tonumber(rideId) or 0)
    if not ride or not ride.endedAt then return false, 'err.ride_not_found' end
    if ride.paid ~= 1 and ride.paid ~= true then return false, 'err.ride_unpaid' end
    local amount = (tonumber(ride.cost) or 0) - (tonumber(ride.refunded) or 0)
    if amount <= 0 then return false, 'err.ride_refunded' end
    local src = onlineSource(ride.renter)
    if not src then return false, 'err.renter_offline' end
    if not money.add(src, CFG.Account, amount, 'scoot-refund') then return false, 'ui.toast.failed' end
    store.rentals.setRefunded(ride.id, (tonumber(ride.refunded) or 0) + amount)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('notify.title'), description = locale('notify.ride_refunded', CFG.Currency, amount), type = 'success' })
    return { amount = amount, renterName = ride.renterName or ride.renter, plate = ride.plate }
end

---Rides in progress, for other resources.
---@return table[] { renter, scooterId, startedAt }
exports('getActiveRentals', function()
    local out = {}
    for id, ride in pairs(active) do out[#out + 1] = { renter = id, scooterId = ride.scooterId, startedAt = ride.startedAt } end
    return out
end)

---Public rental API for phones and other resources. Every call takes the player's server id and
---returns the same `{ success, message?, data? }` shape the app callbacks use, so a phone can hand
---the reply straight to its UI. `message` is already localised.
---@param fn fun(src: integer, ...): any|false, string|nil
---@return fun(src: integer, ...): table
local function apiReply(fn)
    return function(src, ...)
        if not CFG.Enabled then return { success = false, message = locale('err.app_disabled') } end
        local okay, result, err = pcall(fn, src, ...)
        if not okay then
            log.error('rentals', 'export failed: %s', tostring(result))
            return { success = false, message = locale('ui.toast.failed') }
        end
        if result == false or result == nil then return { success = false, message = locale(err or 'ui.toast.failed') } end
        return { success = true, data = result }
    end
end

---Nearby-scooters snapshot for a player, as the app's map shows it.
---@param src integer
---@return table reply { success, data?, message? }
exports('getRentalSnapshot', apiReply(function(src) return rentals.nearby(src) end))
---Rent a parked fleet scooter by id for a player.
---@param src integer
---@param scooterId integer
---@return table reply { success, data = ride, message? }
exports('rentScooter', apiReply(function(src, scooterId) return rentals.rent(src, tonumber(scooterId) or -1) end))
---Rent a scooter dispensed from a bunker for a player, with colour and customisation.
---@param src integer
---@param bunkerId integer
---@param colour any
---@param customization table|nil
---@return table reply { success, data = dispense, message? }
exports('rentAtBunker', apiReply(function(src, bunkerId, colour, customization) return rentals.rentAtBunker(src, tonumber(bunkerId) or -1, colour, customization) end))
---End and bill a player's current ride.
---@param src integer
---@return table reply { success, data = receipt, message? }
exports('endRide', apiReply(function(src) return rentals.finish(src) end))
---A player's past rides.
---@param src integer
---@return table reply { success, data = { rides }, message? }
exports('getRideHistory', apiReply(function(src) return { rides = rentals.history(src) } end))
---A player's ride in progress; `data.ride` is nil when they are not riding.
---@param src integer
---@return table reply { success, data = { ride }, message? }
exports('getCurrentRide', apiReply(function(src) return { ride = rentals.current(src) } end))
---sd-phone's App Store gate for the built-in SCOOT app (`requires = { check = 'sd_scoot.phoneGate' }`).
---The phone already refuses the app while this resource is stopped; this only adds the config switch.
exports('phoneGate', function(_, _)
    return CFG.Enabled == true
end)

---Rental prices and limits from config, for phones and other resources that show them.
---@return table { unlock, currency, rentDistance, refreshMs, enabled }
exports('getRentalPricing', function()
    return { unlock = CFG.UnlockFee, currency = CFG.Currency, rentDistance = CFG.RentDistance, refreshMs = CFG.RefreshMs, enabled = CFG.Enabled }
end)

---Register the module so `require 'server.scoot.rentals'` returns this table.
---@return table
package.preload['server.scoot.rentals'] = function() return rentals end

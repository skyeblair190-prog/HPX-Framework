---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua): ride stats and the admin action log.
local store = require 'server.scoot.store'
---@type table Bunker cache + CRUD (server/scoot/bunkers.lua).
local bunkers = require 'server.scoot.bunkers'
---@type table Scooter fleet (server/scoot/scooters.lua).
local scooters = require 'server.scoot.scooters'
---@type table Charging stations (server/scoot/stations.lua).
local stations = require 'server.scoot.stations'
---@type table Handling profiles (server/scoot/handling.lua).
local handling = require 'server.scoot.handling'
---@type table Rides, billing, force-end and refunds (server/scoot/rentals.lua).
local rentals = require 'server.scoot.rentals'
---@type table Live setting overrides (server/scoot/settings.lua).
local settings = require 'server.scoot.settings'
---@type table Vehicle keys + locks (bridge/server/keys.lua).
local keys = require 'bridge.server.keys'
---@type table Extras catalogue (shared/extras.lua).
local extras = require 'shared.extras'

---@type table Admin tuning (configs/shared/admin.lua).
local CFG = config.Admin
---@type string The ace that opens the panel and every read-only callback. ox_lib grants it to
---Config.Admin.Group (and ViewGroup) when it registers the command below.
local ACE = 'command.' .. CFG.Command
---@type string The ace every change requires: view-only staff get the panel without it.
local EDIT_ACE = CFG.EditAce or 'sd_scoot.edit'
---@type integer Seconds a delete can be undone.
local UNDO_SECONDS = CFG.UndoSeconds or 30
---@type integer Rows per page for ride history and the action log.
local PAGE = 40

ExecuteCommand(('add_ace %s %s allow'):format(CFG.Group, EDIT_ACE))

---Whether a player may open the panel (and read from it).
---@param src integer
---@return boolean
local function canView(src)
    return IsPlayerAceAllowed(src, ACE)
end

---Whether a player may change anything.
---@param src integer
---@return boolean
local function canEdit(src)
    return IsPlayerAceAllowed(src, EDIT_ACE)
end

---Strip values msgpack cannot carry (userdata, functions, NaN/inf) so a callback reply never
---crashes the client with a type error. Tables are walked recursively.
---@param value any
---@return any
local function sanitize(value)
    local t = type(value)
    if t == 'table' then
        local out = {}
        for k, v in pairs(value) do out[k] = sanitize(v) end
        return out
    elseif t == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then return 0 end
        return value
    elseif t == 'string' or t == 'boolean' then
        return value
    end
    return nil
end

---Failure reply with a localised message.
---@param errKey string|nil locale key; defaults to the permission error
---@return table
local function fail(errKey)
    return { success = false, message = locale(errKey or 'err.not_allowed') }
end

---Success reply.
---@param data table|nil
---@return table
local function ok(data)
    return { success = true, data = sanitize(data) }
end

---Stable identifier for audit columns and log lines.
---@param src integer
---@return string
local function identifier(src)
    return GetPlayerIdentifierByType(src, 'license') or ('player:' .. src)
end

---Player name for log lines, capped at 64 characters.
---@param src integer
---@return string display name for logs
local function actorName(src)
    return (GetPlayerName(src) or ('player ' .. src)):sub(1, 64)
end

---The colour table the panel renders swatches from.
---@return table[]
local function colourList()
    local out = {}
    for i, c in ipairs(config.Scooters.Colours) do
        out[i] = { index = i, name = c.name, hex = c.hex }
    end
    return out
end

---The station paint palette, so the panel can draw real swatches.
---@return table[]
local function stationColourList()
    local out = {}
    for i, c in ipairs(config.Stations.Colours or {}) do
        out[i] = { index = i, name = c.name, hex = c.hex }
    end
    return out
end

---Where the admin stands, for the map's "you" dot and the distance column.
---@param src integer
---@return table|nil
local function playerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, heading = GetEntityHeading(ped) }
end

---Local midnight as unix seconds (the server's clock), and the start of the rolling week.
---@return integer today, integer week
local function periodStarts()
    local now = os.date('*t')
    local today = os.time({ year = now.year, month = now.month, day = now.day, hour = 0 })
    return today, today - 6 * 86400
end

---Active rides, with the renter name mirrored onto each rented scooter.
---@return table[] rides, table<integer, table> byScooter
local function activeRides()
    local rides = rentals.active()
    local byScooter = {}
    for _, ride in ipairs(rides) do byScooter[ride.scooterId] = ride end
    return rides, byScooter
end

---The extras catalogue for the new-scooter dialog: every option group and the defaults, no presets.
---@return table
local function extrasCatalog()
    local C = extras.catalog
    return { rear = C.rear, trim = C.trim, lighting = C.lighting, box = C.box, defaults = C.defaults }
end

---Everything the panel shows, in one shape. Sent on open and after every mutation so the panel
---never has to reconcile partial updates.
---@param src integer
---@return table
local function snapshot(src)
    local list = scooters.all()
    local rides, rideByScooter = activeRides()
    local perBunker = {}
    for _, s in ipairs(list) do
        if s.bunkerId then perBunker[s.bunkerId] = (perBunker[s.bunkerId] or 0) + 1 end
        local ride = rideByScooter[s.id]
        if ride then s.rentedBy = ride.renterName end
    end
    local all = bunkers.all()
    for _, b in ipairs(all) do b.scooters = perBunker[b.id] or 0 end
    local B = config.Battery
    local today = periodStarts()
    return {
        bunkers = all,
        stations = stations.all(),
        scooters = list,
        rides = rides,
        today = store.rentals.totals(today),
        battery = { enabled = B.Enabled == true, minToRent = B.MinToRent, fullAt = B.FullAt },
        colours = colourList(),
        extras = extrasCatalog(),
        stationColours = stationColourList(),
        stationLayout = { slotX = config.Stations.SlotX, railStart = config.Stations.RailStart, dockPitch = config.Stations.DockPitch },
        currency = config.Rentals.Currency,
        map = CFG.MapStyle,
        positionsInterval = CFG.PositionsInterval,
        player = playerPos(src),
        canEdit = canEdit(src),
        undoSeconds = UNDO_SECONDS,
    }
end

---@type string|nil The verb being handled, stamped on audit rows.
local currentVerb = nil

---Register one panel callback behind the ace gate. Read callbacks need the panel ace; everything
---else needs the edit ace too. Handler errors are logged and turned into a generic failure reply.
---@param verb string callback suffix (sd_scoot:server:admin:<verb>)
---@param fn fun(src: integer, data: table): table reply
---@param read boolean|nil true for callbacks that change nothing
local function register(verb, fn, read)
    lib.callback.register('sd_scoot:server:admin:' .. verb, function(src, data)
        if not canView(src) then return fail('err.not_allowed') end
        if not read and not canEdit(src) then return fail('err.view_only') end
        currentVerb = verb
        local okay, reply = pcall(fn, src, type(data) == 'table' and data or {})
        currentVerb = nil
        if not okay then
            log.error('admin', '%s failed for %s: %s', verb, tostring(src), tostring(reply))
            return fail('ui.toast.failed')
        end
        return reply
    end)
end

---Log a change: console line plus a row in the persistent action log.
---@param src integer
---@param fmt string
---@param ... any
local function audit(src, fmt, ...)
    local message = fmt:format(...)
    log.info('admin', '%s [%s] %s', actorName(src), src, message)
    store.audit.insert(actorName(src), identifier(src), currentVerb or 'admin', message)
end

---Undo for deletes: the deleted thing is kept briefly and can be rebuilt (with a new id).

---@type table<string, { src: integer, kind: string, data: table, expires: integer }>
local undoable = {}
local undoSeq = 0

---Keep a deleted record for UNDO_SECONDS so the actor can undo it, pruning expired entries.
---@param src integer
---@param kind 'bunker'|'station'|'scooter'
---@param data table
---@return string token
local function keepForUndo(src, kind, data)
    undoSeq = undoSeq + 1
    local token = ('%d-%d'):format(os.time(), undoSeq)
    undoable[token] = { src = src, kind = kind, data = data, expires = os.time() + UNDO_SECONDS }
    for key, u in pairs(undoable) do
        if u.expires < os.time() then undoable[key] = nil end
    end
    return token
end

---snapshot (read): the full panel state, sent when the panel opens.
---@param src integer
register('snapshot', function(src)
    return ok(snapshot(src))
end, true)

---createBunker: place a new bunker and reply with the row plus a fresh snapshot.
---@param src integer
---@param data table { name, x, y, z, heading }
register('createBunker', function(src, data)
    local row, err = bunkers.create(data, identifier(src))
    if not row then return fail(err) end
    audit(src, 'created bunker #%d %s', row.id, row.name)
    return ok({ bunker = row, snapshot = snapshot(src) })
end)

---renameBunker: give a bunker a new name.
---@param src integer
---@param data table { id, name }
register('renameBunker', function(src, data)
    local done, err = bunkers.rename(data.id, data.name)
    if not done then return fail(err) end
    audit(src, 'renamed bunker #%s to %s', tostring(data.id), tostring(data.name))
    return ok({ snapshot = snapshot(src) })
end)

---toggleBunker: enable or disable a bunker.
---@param src integer
---@param data table { id, enabled }
register('toggleBunker', function(src, data)
    local done, err = bunkers.setEnabled(data.id, data.enabled and true or false)
    if not done then return fail(err) end
    audit(src, '%s bunker #%s', data.enabled and 'enabled' or 'disabled', tostring(data.id))
    return ok({ snapshot = snapshot(src) })
end)

---moveBunker: move a bunker to new coordinates and reply with the updated row.
---@param src integer
---@param data table { id, x, y, z, heading }
register('moveBunker', function(src, data)
    local done, err = bunkers.move(data.id, data)
    if not done then return fail(err) end
    audit(src, 'moved bunker #%s', tostring(data.id))
    return ok({ bunker = bunkers.get(data.id), snapshot = snapshot(src) })
end)

---setBunkerStock: set how many scooters a bunker holds in stock.
---@param src integer
---@param data table { id, stock }
register('setBunkerStock', function(src, data)
    local b = bunkers.get(data.id)
    local done, err = bunkers.setStock(data.id, data.stock)
    if not done then return fail(err) end
    audit(src, 'set stock of bunker #%s %s to %s', tostring(data.id), b and b.name or '?', tostring(data.stock))
    return ok({ snapshot = snapshot(src) })
end)

---deleteBunker: remove a bunker and reply with an undo token that can rebuild it.
---@param src integer
---@param data table { id }
register('deleteBunker', function(src, data)
    local b = bunkers.get(data.id)
    if not b then return fail('err.no_bunker') end
    local keep = { name = b.name, x = b.x, y = b.y, z = b.z, heading = b.heading, enabled = b.enabled, stock = b.stock }
    local done, err = bunkers.remove(data.id)
    if not done then return fail(err) end
    audit(src, 'deleted bunker #%s %s', tostring(data.id), keep.name)
    return ok({ snapshot = snapshot(src), undo = keepForUndo(src, 'bunker', keep) })
end)

---deleteAllBunkers: wipe every bunker at once. The caller sends the count its panel showed, so a
---list that grew or shrank since the dialog opened aborts rather than deleting something unseen.
---There is no undo for this one; the confirm dialog says so.
---@param src integer
---@param data table { count }
register('deleteAllBunkers', function(src, data)
    local all = bunkers.all()
    if tonumber(data and data.count) ~= #all then return fail('err.list_changed') end
    local gone, failed = 0, 0
    for _, b in ipairs(all) do
        local done = bunkers.remove(b.id)
        if done then gone = gone + 1 else failed = failed + 1 end
    end
    audit(src, 'deleted every bunker: %d removed, %d failed', gone, failed)
    return ok({ snapshot = snapshot(src), removed = gone, failed = failed })
end)

---deleteAllStations: the same wipe for charging stations. Docked scooters are released by the
---stations module's removal listeners.
---@param src integer
---@param data table { count }
register('deleteAllStations', function(src, data)
    local all = stations.all()
    if tonumber(data and data.count) ~= #all then return fail('err.list_changed') end
    local gone, failed = 0, 0
    for _, st in ipairs(all) do
        local done = stations.remove(st.id)
        if done then gone = gone + 1 else failed = failed + 1 end
    end
    audit(src, 'deleted every charging station: %d removed, %d failed', gone, failed)
    return ok({ snapshot = snapshot(src), removed = gone, failed = failed })
end)

---createStation: place a new charging station and reply with the row plus a fresh snapshot.
---@param src integer
---@param data table { name, x, y, z, heading, count?, colour? }
register('createStation', function(src, data)
    local row, err = stations.create(data, identifier(src))
    if not row then return fail(err) end
    audit(src, 'created station #%d %s', row.id, row.name)
    return ok({ station = row, snapshot = snapshot(src) })
end)

---renameStation: give a charging station a new name.
---@param src integer
---@param data table { id, name }
register('renameStation', function(src, data)
    local done, err = stations.rename(data.id, data.name)
    if not done then return fail(err) end
    audit(src, 'renamed station #%s to %s', tostring(data.id), tostring(data.name))
    return ok({ snapshot = snapshot(src) })
end)

---toggleStation: enable or disable a charging station.
---@param src integer
---@param data table { id, enabled }
register('toggleStation', function(src, data)
    local done, err = stations.setEnabled(data.id, data.enabled and true or false)
    if not done then return fail(err) end
    audit(src, '%s station #%s', data.enabled and 'enabled' or 'disabled', tostring(data.id))
    return ok({ snapshot = snapshot(src) })
end)

---moveStation: move a station to new coordinates and reply with the updated row.
---@param src integer
---@param data table { id, x, y, z, heading }
register('moveStation', function(src, data)
    local done, err = stations.move(data.id, data)
    if not done then return fail(err) end
    audit(src, 'moved station #%s', tostring(data.id))
    return ok({ station = stations.get(data.id), snapshot = snapshot(src) })
end)

---setStationColour: repaint a station from the station palette.
---@param src integer
---@param data table { id, colour }
register('setStationColour', function(src, data)
    local done, err = stations.setColour(data.id, data.colour)
    if not done then return fail(err) end
    audit(src, 'painted station #%s colour %s', tostring(data.id), tostring(data.colour))
    return ok({ snapshot = snapshot(src) })
end)

---setStationSlots: change how many docks a station has.
---@param src integer
---@param data table { id, count }
register('setStationSlots', function(src, data)
    local done, err = stations.setCount(data.id, data.count)
    if not done then return fail(err) end
    audit(src, 'set station #%s to %s dock(s)', tostring(data.id), tostring(data.count))
    return ok({ snapshot = snapshot(src) })
end)

---releaseDock: free one dock on a station and undock the scooter that sat in it.
---@param src integer
---@param data table { stationId, slot }
register('releaseDock', function(src, data)
    local st = stations.get(data.stationId)
    if not st then return fail('err.no_station') end
    local slot = math.tointeger(tonumber(data.slot) or 0) or 0
    local occupant = st.slots[slot]
    if not occupant then return fail('err.dock_empty') end
    stations.release(st.id, slot)
    scooters.undock(occupant.scooterId)
    audit(src, 'released %s from %s dock %d', tostring(occupant.plate or occupant.scooterId), st.name, slot)
    return ok({ snapshot = snapshot(src) })
end)

---deleteStation: remove a station and reply with an undo token that can rebuild it.
---@param src integer
---@param data table { id }
register('deleteStation', function(src, data)
    local st = stations.get(data.id)
    if not st then return fail('err.no_station') end
    local keep = { name = st.name, x = st.x, y = st.y, z = st.z, heading = st.heading, count = st.count, colour = st.colour, enabled = st.enabled }
    local done, err = stations.remove(data.id)
    if not done then return fail(err) end
    audit(src, 'deleted station #%s %s', tostring(data.id), keep.name)
    return ok({ snapshot = snapshot(src), undo = keepForUndo(src, 'station', keep) })
end)

---createScooter: add a scooter to the fleet at the given spot.
---@param src integer
---@param data table { x, y, z, heading, colour, bunkerId?, customization? }
register('createScooter', function(src, data)
    local scooter, err = scooters.create(data, identifier(src))
    if not scooter then return fail(err) end
    audit(src, 'created scooter #%d %s', scooter.id, scooter.plate)
    return ok({ scooter = scooter, snapshot = snapshot(src) })
end)

---spawnScooterOnMe: spawn a scooter at the admin's feet, unlock it and hand them the keys.
---Replies with its net id so the client can find the entity.
---@param src integer
---@param data table { colour, bunkerId?, customization? }
register('spawnScooterOnMe', function(src, data)
    local at = playerPos(src)
    if not at then return fail('ui.toast.failed') end
    local scooter, err = scooters.create({
        x = at.x, y = at.y, z = at.z - 0.6, heading = at.heading,
        colour = data.colour, bunkerId = data.bunkerId, customization = data.customization,
    }, identifier(src))
    if not scooter then return fail(err) end
    local entry = scooters.get(scooter.id)
    local entity = entry and entry.entity
    if not entity or not DoesEntityExist(entity) then return fail('err.spawn_failed') end
    scooters.setLocked(scooter.id, false)
    keys.give(src, entity)
    audit(src, 'spawned scooter #%d %s on themselves', scooter.id, scooter.plate)
    return ok({ scooter = scooter, netId = NetworkGetNetworkIdFromEntity(entity), snapshot = snapshot(src) })
end)

---spawnAtBunker: spawn a scooter out of a bunker's stock.
---@param src integer
---@param data table { bunkerId, colour, customization? }
register('spawnAtBunker', function(src, data)
    local scooter, err = scooters.spawnAtBunker(data.bunkerId, data.colour, identifier(src), data.customization)
    if not scooter then return fail(err) end
    audit(src, 'spawned scooter #%d %s at bunker #%s', scooter.id, scooter.plate, tostring(data.bunkerId))
    return ok({ scooter = scooter, snapshot = snapshot(src) })
end)

---Delete one scooter, refusing a rented one. Returns what an undo needs.
---@param id integer
---@return table|false keep
---@return string|nil errKey
local function deleteScooter(id)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    if rentals.renterOf(entry.row.id) then return false, 'err.scooter_rented' end
    local r = entry.row
    local x, y, z, heading = r.x, r.y, r.z, r.heading
    if entry.entity and DoesEntityExist(entry.entity) then
        local c = GetEntityCoords(entry.entity)
        x, y, z, heading = c.x, c.y, c.z, GetEntityHeading(entry.entity)
    end
    local keep = { plate = r.plate, colour = r.colour, bunkerId = r.bunkerId, battery = r.battery, customization = r.customization, x = x, y = y, z = z, heading = heading }
    if r.stationId and r.slot then stations.release(r.stationId, r.slot) end
    local done, err = scooters.remove(id)
    if not done then return false, err end
    return keep
end

---deleteScooter: delete one scooter that is not rented and reply with an undo token.
---@param src integer
---@param data table { id }
register('deleteScooter', function(src, data)
    local keep, err = deleteScooter(data.id)
    if not keep then return fail(err) end
    audit(src, 'deleted scooter #%s %s', tostring(data.id), keep.plate)
    return ok({ snapshot = snapshot(src), undo = keepForUndo(src, 'scooter', keep) })
end)

---undoDelete: rebuild a deleted bunker, station or scooter while its undo token is still valid.
---The restored thing gets a new id; a scooter whose bunker is gone comes back without a home.
---@param src integer
---@param data table { token }
register('undoDelete', function(src, data)
    local u = undoable[tostring(data.token)]
    if not u or u.expires < os.time() then return fail('err.undo_expired') end
    undoable[tostring(data.token)] = nil
    local d = u.data
    if u.kind == 'bunker' then
        local row, err = bunkers.create(d, identifier(src))
        if not row then return fail(err) end
        bunkers.setStock(row.id, d.stock or 0)
        if not d.enabled then bunkers.setEnabled(row.id, false) end
        audit(src, 'restored bunker %s as #%d', d.name, row.id)
    elseif u.kind == 'station' then
        local row, err = stations.create(d, identifier(src))
        if not row then return fail(err) end
        if not d.enabled then stations.setEnabled(row.id, false) end
        audit(src, 'restored station %s as #%d', d.name, row.id)
    else
        if d.bunkerId and not bunkers.get(d.bunkerId) then d.bunkerId = nil end
        local view, err = scooters.create(d, identifier(src))
        if not view then return fail(err) end
        scooters.setBattery(view.id, d.battery or 100)
        audit(src, 'restored scooter %s as #%d %s', d.plate, view.id, view.plate)
    end
    return ok({ snapshot = snapshot(src) })
end)

---respawnScooter: recreate a scooter's vehicle at its stored position.
---@param src integer
---@param data table { id }
register('respawnScooter', function(src, data)
    local done, err = scooters.respawn(data.id)
    if not done then return fail(err) end
    audit(src, 'respawned scooter #%s', tostring(data.id))
    return ok({ snapshot = snapshot(src) })
end)

---setScooterColour: repaint a scooter from the scooter palette.
---@param src integer
---@param data table { id, colour }
register('setScooterColour', function(src, data)
    local done, err = scooters.setColour(data.id, data.colour)
    if not done then return fail(err) end
    audit(src, 'repainted scooter #%s to colour %s', tostring(data.id), tostring(data.colour))
    return ok({ snapshot = snapshot(src) })
end)

---setScooterBattery: set a scooter's battery level.
---@param src integer
---@param data table { id, level }
register('setScooterBattery', function(src, data)
    local entry = scooters.get(data.id)
    local done, err = scooters.setBatteryLevel(data.id, data.level)
    if not done then return fail(err) end
    audit(src, 'set battery of %s to %s%%', entry and entry.row.plate or ('#' .. tostring(data.id)), tostring(data.level))
    return ok({ snapshot = snapshot(src) })
end)

---lockScooter: lock or unlock a scooter, refusing one that is rented.
---@param src integer
---@param data table { id, locked }
register('lockScooter', function(src, data)
    local entry = scooters.get(data.id)
    if entry and rentals.renterOf(entry.row.id) then return fail('err.scooter_rented') end
    local done, err = scooters.setLocked(data.id, data.locked and true or false)
    if not done then return fail(err) end
    audit(src, '%s %s', data.locked and 'locked' or 'unlocked', entry and entry.row.plate or ('#' .. tostring(data.id)))
    return ok({ snapshot = snapshot(src) })
end)

---bringScooter: move a scooter that is not rented to two metres in front of the admin.
---@param src integer
---@param data table { id }
register('bringScooter', function(src, data)
    local entry = scooters.get(data.id)
    if not entry then return fail('err.no_scooter') end
    if rentals.renterOf(entry.row.id) then return fail('err.scooter_rented') end
    local at = playerPos(src)
    if not at then return fail('ui.toast.failed') end
    local h = math.rad(at.heading)
    local x, y = at.x - math.sin(h) * 2.0, at.y + math.cos(h) * 2.0
    local done, err = scooters.moveTo(data.id, x, y, at.z - 0.5, at.heading)
    if not done then return fail(err) end
    audit(src, 'brought %s to themselves', entry.row.plate)
    return ok({ snapshot = snapshot(src) })
end)

---Send a scooter back into its home bunker's stock. Returns the plate and bunker name.
---@param id integer
---@return table|false result
---@return string|nil errKey
local function sendHome(id)
    local entry = scooters.get(id)
    if not entry then return false, 'err.no_scooter' end
    if rentals.renterOf(entry.row.id) then return false, 'err.scooter_rented' end
    local home = entry.row.bunkerId and bunkers.get(entry.row.bunkerId) or nil
    if not home then return false, 'err.no_home' end
    if entry.row.stationId and entry.row.slot then stations.release(entry.row.stationId, entry.row.slot) end
    local plate = entry.row.plate
    local done, err = scooters.remove(entry.row.id)
    if not done then return false, err end
    bunkers.adjustStock(home.id, 1)
    return { plate = plate, bunker = home.name }
end

---sendHome: return a scooter to its home bunker's stock.
---@param src integer
---@param data table { id }
register('sendHome', function(src, data)
    local result, err = sendHome(data.id)
    if not result then return fail(err) end
    audit(src, 'sent %s home to %s', result.plate, result.bunker)
    return ok({ snapshot = snapshot(src) })
end)

---@type table<string, fun(src: integer, id: integer, data: table): boolean|table|false, string|nil>
local BULK = {
    respawn = function(_, id) return scooters.respawn(id) end,
    delete = function(_, id) return deleteScooter(id) end,
    battery = function(_, id, data) return scooters.setBatteryLevel(id, data.level) end,
    lock = function(_, id)
        local entry = scooters.get(id)
        if entry and rentals.renterOf(entry.row.id) then return false, 'err.scooter_rented' end
        return scooters.setLocked(id, true)
    end,
    unlock = function(_, id)
        local entry = scooters.get(id)
        if entry and rentals.renterOf(entry.row.id) then return false, 'err.scooter_rented' end
        return scooters.setLocked(id, false)
    end,
    sendHome = function(_, id) return sendHome(id) end,
}

---bulkScooters: run one BULK action over many scooters, counting how many succeeded and how many
---were skipped (one failure never stops the rest).
---@param src integer
---@param data table { action, ids, level? }
register('bulkScooters', function(src, data)
    local run = BULK[data.action]
    if not run or type(data.ids) ~= 'table' then return fail('ui.toast.failed') end
    local done, failed = 0, 0
    for _, id in ipairs(data.ids) do
        local okay, result = pcall(run, src, tonumber(id), data)
        if okay and result then done = done + 1 else failed = failed + 1 end
    end
    audit(src, 'bulk %s on %d scooter(s): %d done, %d skipped', tostring(data.action), #data.ids, done, failed)
    return ok({ done = done, failed = failed, snapshot = snapshot(src) })
end)

---teleport (read): the coordinates of a bunker, station or scooter for the client to teleport to.
---A spawned scooter reports its live entity position, otherwise its stored one.
---@param src integer
---@param data table { kind: 'bunker'|'station'|nil, id }
register('teleport', function(src, data)
    if data.kind == 'bunker' then
        local b = bunkers.get(data.id)
        if not b then return fail('err.no_bunker') end
        return ok({ x = b.x, y = b.y, z = b.z })
    elseif data.kind == 'station' then
        local st = stations.get(data.id)
        if not st then return fail('err.no_station') end
        return ok({ x = st.x, y = st.y, z = st.z })
    end
    local entry = scooters.get(data.id)
    if not entry then return fail('err.no_scooter') end
    local x, y, z
    local e = entry.entity
    if e and DoesEntityExist(e) then
        local c = GetEntityCoords(e)
        x, y, z = c.x, c.y, c.z
    else
        x, y, z = entry.row.x, entry.row.y, entry.row.z
    end
    return ok({ x = x, y = y, z = z })
end, true)

---teleportPoint (read): check a map point the admin clicked is in range and echo it back for the teleport.
---@param src integer
---@param data table { x, y }
register('teleportPoint', function(src, data)
    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return fail('err.bad_coords') end
    log.info('admin', '%s teleported to map point %.0f, %.0f', actorName(src), x, y)
    return ok({ x = x, y = y })
end, true)

---positions (read): live scooter, admin and rider positions for the map's polling refresh.
---@param src integer
register('positions', function(src)
    local rides = rentals.active()
    local riders = {}
    for _, ride in ipairs(rides) do
        riders[#riders + 1] = { rideId = ride.id, scooterId = ride.scooterId, name = ride.renterName, plate = ride.plate, minutes = ride.minutes, x = ride.x, y = ride.y }
    end
    return ok({ scooters = scooters.positions(), player = playerPos(src), riders = riders })
end, true)

---mapActivity (read): recent ride points for the map's activity layer.
register('mapActivity', function()
    local points = store.rentals.points(CFG.ActivityPoints or 400)
    return ok({ points = points })
end, true)

---Rides & revenue.

---rides (read): active rides, today/week/all-time totals, per-bunker figures for the week and the
---last 24 hours bucketed by hour.
register('rides', function()
    local today, week = periodStarts()
    local byBunker = store.rentals.byBunker(week)
    for _, row in ipairs(byBunker) do
        local b = row.bunkerId and bunkers.get(row.bunkerId)
        row.name = b and b.name or nil
        row.rides, row.revenue = tonumber(row.rides) or 0, tonumber(row.revenue) or 0
    end
    local hourStart = math.floor(os.time() / 3600) - 23
    local hourly = {}
    for _, row in ipairs(store.rentals.hourly(hourStart * 3600)) do
        hourly[#hourly + 1] = { hour = tonumber(row.hour), rides = tonumber(row.rides) or 0, revenue = tonumber(row.revenue) or 0 }
    end
    return ok({
        active = rentals.active(),
        totals = { today = store.rentals.totals(today), week = store.rentals.totals(week), all = store.rentals.totals(0) },
        byBunker = byBunker,
        hourly = hourly,
        firstHour = hourStart,
        currency = config.Rentals.Currency,
    })
end, true)

---rideHistory (read): one page of past rides, optionally filtered by a search query.
---@param data table { query?, offset? }
register('rideHistory', function(_, data)
    local query = type(data.query) == 'string' and data.query:sub(1, 48) or nil
    local offset = math.max(0, math.tointeger(tonumber(data.offset) or 0) or 0)
    local rows, total = store.rentals.search(query, PAGE, offset)
    return ok({ rows = rows, total = total, offset = offset, pageSize = PAGE })
end, true)

---playerRides (read): the last 100 rides of one renter.
---@param data table { renter }
register('playerRides', function(_, data)
    if type(data.renter) ~= 'string' then return fail('ui.toast.failed') end
    return ok({ rows = store.rentals.byRenter(data.renter, 100) })
end, true)

---forceEndRide: end someone's active ride from the panel.
---@param src integer
---@param data table { rideId }
register('forceEndRide', function(src, data)
    local result, err = rentals.forceEnd(data.rideId)
    if not result then return fail(err) end
    audit(src, 'force-ended the ride of %s on %s', result.renterName, result.plate)
    return ok({ snapshot = snapshot(src) })
end)

---refundRide: refund a ride's charge to its renter.
---@param src integer
---@param data table { rideId }
register('refundRide', function(src, data)
    local result, err = rentals.refund(data.rideId)
    if not result then return fail(err) end
    audit(src, 'refunded %s%d to %s for ride #%s on %s', config.Rentals.Currency, result.amount, result.renterName, tostring(data.rideId), tostring(result.plate))
    return ok({ amount = result.amount })
end)

---Admin action log.

---auditLog (read): one page of the admin action log, optionally filtered by a search query.
---@param data table { query?, offset? }
register('auditLog', function(_, data)
    local query = type(data.query) == 'string' and data.query:sub(1, 48) or nil
    local offset = math.max(0, math.tointeger(tonumber(data.offset) or 0) or 0)
    local rows, total = store.audit.list(query, PAGE, offset)
    return ok({ rows = rows, total = total, offset = offset, pageSize = PAGE })
end, true)

---Live settings.

---settings (read): everything the Settings tab shows.
register('settings', function()
    return ok({ settings = settings.bundle() })
end, true)

---settingsSave: save live setting changes, auditing each changed line.
---@param src integer
---@param data table { values }
register('settingsSave', function(src, data)
    local changed, err = settings.save(data.values, actorName(src))
    if not changed then return fail(err) end
    for _, line in ipairs(changed) do audit(src, 'setting %s', line) end
    return ok({ changed = #changed, settings = settings.bundle(), snapshot = snapshot(src) })
end)

---settingsReset: drop every live override so the config file values apply again.
---@param src integer
register('settingsReset', function(src)
    local n = settings.resetAll()
    audit(src, 'reset %d live setting(s) to the config file', n)
    return ok({ settings = settings.bundle(), snapshot = snapshot(src) })
end)

---Handling editor. Every reply carries the whole bundle so the tab re-renders from one source.

---handling (read): everything the Handling tab shows.
register('handling', function()
    return ok({ handling = handling.bundle() })
end, true)

---handlingCreate: create a handling profile and reply with its id.
---@param src integer
---@param data table { name, from?: 'defaults' | 'template' | 'profile', index?, id? }
register('handlingCreate', function(src, data)
    local profile, err = handling.create(data, actorName(src))
    if not profile then return fail(err) end
    audit(src, 'created handling profile #%d %s', profile.id, profile.name)
    return ok({ id = profile.id, handling = handling.bundle() })
end)

---handlingSave: save a handling profile's overrides and reply with how many fields changed.
---@param src integer
---@param data table { id, values }
register('handlingSave', function(src, data)
    local changes, err = handling.save(data.id, data.values, actorName(src))
    if not changes then return fail(err) end
    local count = 0
    for _ in pairs(changes) do count = count + 1 end
    audit(src, 'saved handling profile #%s (%d field(s) changed)', tostring(data.id), count)
    return ok({ changed = count, handling = handling.bundle() })
end)

---handlingActivate: make a handling profile the active one.
---@param src integer
---@param data table { id }
register('handlingActivate', function(src, data)
    local done, err = handling.activate(data.id)
    if not done then return fail(err) end
    audit(src, 'activated handling profile #%s', tostring(data.id))
    return ok({ handling = handling.bundle() })
end)

---handlingRename: give a handling profile a new name.
---@param src integer
---@param data table { id, name }
register('handlingRename', function(src, data)
    local done, err = handling.rename(data.id, data.name)
    if not done then return fail(err) end
    audit(src, 'renamed handling profile #%s to %s', tostring(data.id), tostring(data.name))
    return ok({ handling = handling.bundle() })
end)

---handlingDelete: delete a handling profile.
---@param src integer
---@param data table { id }
register('handlingDelete', function(src, data)
    local done, err = handling.remove(data.id)
    if not done then return fail(err) end
    audit(src, 'deleted handling profile #%s', tostring(data.id))
    return ok({ handling = handling.bundle() })
end)

---handlingExport (read): handling.meta text with the given values written in, ready to paste over the file.
---@param data table { values }
register('handlingExport', function(_, data)
    return ok({ text = handling.export(data.values) })
end, true)

---handlingUndo: put back the fields one logged handling save changed.
---@param src integer
---@param data table { logId }
register('handlingUndo', function(src, data)
    local changes, err = handling.undo(data.logId, actorName(src))
    if not changes then return fail(err) end
    audit(src, 'undid handling change #%s', tostring(data.logId))
    return ok({ handling = handling.bundle() })
end)

---The panel command, restricted to Config.Admin.Group (and ViewGroup): opens the admin panel on the
---caller's client.
lib.addCommand(CFG.Command, {
    help = 'Open the SCOOT fleet admin panel',
    restricted = CFG.ViewGroup and { CFG.Group, CFG.ViewGroup } or CFG.Group,
}, function(source)
    TriggerClientEvent('sd_scoot:client:openAdmin', source)
end)

---Debug: lift the nearest bunker out of the ground on the caller's client so it can be inspected.
lib.addCommand(CFG.LiftCommand, {
    help = 'Toggle lifting the nearest SCOOT bunker out of the ground (local, debug)',
    params = {
        { name = 'height', type = 'number', help = 'Metres above ground level (default 0)', optional = true },
    },
    restricted = CFG.Group,
}, function(source, args)
    TriggerClientEvent('sd_scoot:client:liftBunker', source, args.height)
end)

---Turn offsets around a player into world points that sit on the ground. A ped's coordinates are a
---metre above its feet, so the caller's client probes the real ground height for every point;
---without that, a station stores a z a metre high and the scooters docked in it hang in the air.
---@param source integer
---@param items table[] each { ahead, across } in metres (ahead along the caller's view, across to their right)
---@return table[]|nil points each { x, y, z }
---@return number heading the caller's heading
local function showcasePoints(source, items)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil, 0.0 end
    local at = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local facing = math.rad(heading)
    local forward = { x = -math.sin(facing), y = math.cos(facing) }
    local right = { x = math.cos(facing), y = math.sin(facing) }
    local points = {}
    for i, item in ipairs(items) do
        points[i] = {
            x = at.x + forward.x * (item.ahead or 0.0) + right.x * (item.across or 0.0),
            y = at.y + forward.y * (item.ahead or 0.0) + right.y * (item.across or 0.0),
            z = at.z,
        }
    end
    local ground = lib.callback.await('sd_scoot:client:groundZ', source, points)
    for i, point in ipairs(points) do
        point.z = tonumber(ground and ground[i]) or (at.z - 1.0)
    end
    return points, heading
end

---@type table<string, integer[]> caller identifier -> scooter ids from their last /scootcircle
local circles = {}

---Toast a debug command's result back to the caller.
---@param src integer
---@param description string
---@param kind 'success'|'error'|'inform'
local function notify(src, description, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('notify.title'), description = description, type = kind })
end

---Debug: one scooter of every paint in a ring around the caller, each facing the middle, so the
---whole palette can be compared at a glance. `clear` deletes the ring this caller last spawned.
lib.addCommand(CFG.CircleCommand, {
    help = 'Park one scooter of every colour in a ring around you: /' .. CFG.CircleCommand .. ' [metres|clear] (debug)',
    restricted = CFG.Group,
}, function(source, args)
    local who = identifier(source)
    local wants = tostring(args[1] or ''):lower()
    if wants == 'clear' then
        local ids = circles[who] or {}
        local gone = 0
        for _, id in ipairs(ids) do
            if scooters.remove(id) then gone = gone + 1 end
        end
        circles[who] = nil
        audit(source, 'cleared a scooter ring of %d', gone)
        return notify(source, ('Removed %d scooter(s)'):format(gone), gone > 0 and 'success' or 'inform')
    end

    local radius = math.max(3.0, math.min(40.0, tonumber(wants) or CFG.CircleRadius or 7.0))
    local palette = config.Scooters.Colours
    local step = 360.0 / #palette
    local spots = {}
    for i = 1, #palette do
        local turn = math.rad(step * (i - 1))
        spots[i] = { ahead = radius * math.cos(turn), across = radius * math.sin(turn) }
    end
    local points, heading = showcasePoints(source, spots)
    if not points then return notify(source, 'You need to be in the world', 'error') end
    local ids, failed = {}, 0
    for i = 1, #palette do
        local at = points[i]
        local view, err = scooters.create({
            x = at.x, y = at.y, z = at.z,
            heading = (heading + step * (i - 1) + 180.0) % 360.0,
            colour = i,
        }, 'circle:' .. who)
        if view then ids[#ids + 1] = view.id else failed = failed + 1; log.warn('admin', 'circle: colour %d failed (%s)', i, tostring(err)) end
    end
    circles[who] = ids
    audit(source, 'spawned a ring of %d scooter(s) at %.1f m', #ids, radius)
    notify(source, ('%d scooter(s) parked in a %.1f m ring%s'):format(#ids, radius, failed > 0 and (', %d failed'):format(failed) or ''), 'success')
end)

---@type table<string, integer[]> caller identifier -> station ids from their last /scootdocks line-up
local dockRings = {}
---@type table<string, integer[]> caller identifier -> station ids from their last /scootsizes line-up
local sizeRows = {}

---Place charging stations in front of a player, every one turned to face back at them. Offsets are
---in metres from where the caller stands: `ahead` along their view, `across` to their right.
---@param source integer
---@param items table[] each { name, count, colour, ahead, across }
---@return integer[] ids
---@return integer failed
local function placeStations(source, items)
    local points, heading = showcasePoints(source, items)
    if not points then return {}, #items end
    local who = identifier(source)
    local ids, failed = {}, 0
    for i, item in ipairs(items) do
        local at = points[i]
        local placed, err = stations.create({
            name = item.name,
            x = at.x, y = at.y, z = at.z,
            heading = (heading + 180.0) % 360.0,
            count = item.count,
            colour = item.colour,
        }, 'showcase:' .. who)
        if placed then ids[#ids + 1] = placed.id else failed = failed + 1; log.warn('admin', 'showcase: %s failed (%s)', tostring(item.name), tostring(err)) end
    end
    return ids, failed
end

---Delete a tracked showcase and report how many went.
---@param who string caller identifier
---@param kept table<string, integer[]> the table tracking that caller's ids
---@return integer removed
local function clearStations(who, kept)
    local gone = 0
    for _, id in ipairs(kept[who] or {}) do
        if stations.remove(id) then gone = gone + 1 end
    end
    kept[who] = nil
    return gone
end

---Debug: every shell colour lined up in front of the caller like a showroom, rows of DockPerRow
---all facing back at them. `clear` deletes the line-up this caller last spawned.
lib.addCommand(CFG.DockCommand, {
    help = 'Line up one charging station of every colour in front of you: /' .. CFG.DockCommand .. ' [metres|clear] (debug)',
    restricted = CFG.Group,
}, function(source, args)
    local who = identifier(source)
    local wants = tostring(args[1] or ''):lower()
    if wants == 'clear' then
        local gone = clearStations(who, dockRings)
        audit(source, 'cleared a station line-up of %d', gone)
        return notify(source, ('Removed %d charging station(s)'):format(gone), gone > 0 and 'success' or 'inform')
    end

    local palette = config.Stations.Colours
    local spacing = math.max(5.0, math.min(20.0, tonumber(wants) or CFG.DockSpacing or 6.0))
    local perRow = math.max(1, math.min(#palette, CFG.DockPerRow or 5))
    local rowGap = CFG.DockRowGap or 9.0
    local items = {}
    for i = 1, #palette do
        local row = math.floor((i - 1) / perRow)
        local column = (i - 1) % perRow
        local wide = math.min(perRow, #palette - row * perRow)
        items[i] = {
            name = palette[i].name,
            count = config.Stations.MaxSlots,
            colour = i,
            ahead = (CFG.DockAhead or 10.0) + row * rowGap,
            across = (column - (wide - 1) / 2) * spacing,
        }
    end
    local ids, failed = placeStations(source, items)
    dockRings[who] = ids
    audit(source, 'lined up %d charging station(s)', #ids)
    notify(source, ('%d charging station(s) lined up ahead%s'):format(#ids, failed > 0 and (', %d failed'):format(failed) or ''), 'success')
end)

---Debug: one charging station of every size, biggest first, in a straight line in front of the
---caller so the dock counts can be compared side by side. `clear` removes the last line.
lib.addCommand(CFG.SizeCommand, {
    help = 'Line up a charging station of every dock count, largest first: /' .. CFG.SizeCommand .. ' [metres|clear] (debug)',
    restricted = CFG.Group,
}, function(source, args)
    local who = identifier(source)
    local wants = tostring(args[1] or ''):lower()
    if wants == 'clear' then
        local gone = clearStations(who, sizeRows)
        audit(source, 'cleared a station size line of %d', gone)
        return notify(source, ('Removed %d charging station(s)'):format(gone), gone > 0 and 'success' or 'inform')
    end

    local most = config.Stations.MaxSlots
    local spacing = math.max(5.0, math.min(20.0, tonumber(wants) or CFG.SizeSpacing or 7.0))
    local items = {}
    for i = 1, most do
        local count = most - i + 1
        items[i] = {
            name = count == 1 and '1 dock' or ('%d docks'):format(count),
            count = count,
            colour = config.Stations.DefaultColour or 1,
            ahead = CFG.SizeAhead or 9.0,
            across = (i - 1 - (most - 1) / 2) * spacing,
        }
    end
    local ids, failed = placeStations(source, items)
    sizeRows[who] = ids
    audit(source, 'lined up %d charging station size(s)', #ids)
    notify(source, ('%d charging station(s) from %d docks down to 1%s'):format(#ids, most, failed > 0 and (', %d failed'):format(failed) or ''), 'success')
end)

---Live model reload after `restart sd_scoot_assets`: idle scooters are despawned so their model
---is unreferenced, every client drops its props and models and rebuilds from the new files, then
---the fleet comes back. Rented scooters are left alone (their rider keeps the old model until the
---ride ends).
lib.addCommand(CFG.FlushCommand, {
    help = 'Reload the SCOOT models on every client after restarting sd_scoot_assets',
    restricted = CFG.Group,
}, function(source)
    local gone = scooters.despawnIdle()
    TriggerClientEvent('sd_scoot:client:flush', -1)
    log.info('admin', '%s flushed the models: %d idle scooter(s) despawned', identifier(source), gone)
    SetTimeout(CFG.FlushRespawnMs, function()
        local back = scooters.spawnMissing()
        log.info('admin', 'flush: %d scooter(s) respawned', back)
    end)
end)

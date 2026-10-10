---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'

---@type table Station tuning (configs/shared/stations.lua).
local CFG = config.Stations
---@type string GlobalState key the enabled stations are published under; clients stream from it.
local STATE_KEY = 'sd_scoot:stations'

---@type table Stations module; the table returned at end of file.
local stations = {}

---@type table<integer, table> Every row by id, enabled or not. The database is only read at boot.
local cache = {}
---@type fun(id: integer)[] Listeners told when a station is deleted (scooters free their slot).
local removedListeners = {}
---@type fun(id: integer)[] Listeners told when a station is moved (docked scooters follow it).
local movedListeners = {}

---Dock count clamped to what the prop family can build; nil or junk means the configured default.
---@param n any
---@return integer
local function validCount(n)
    n = math.tointeger(tonumber(n) or 0) or 0
    if n < 1 then return CFG.Slots end
    return math.min(n, CFG.MaxSlots)
end

---Paint index clamped to the palette; nil or junk means the configured default.
---@param n any
---@return integer
local function validColour(n)
    n = math.tointeger(tonumber(n) or 0) or 0
    if n < 1 or n > #CFG.Colours then return CFG.DefaultColour or 1 end
    return n
end

---Empty slot table for a station: `false` per dock.
---@param count integer
---@return table
local function emptySlots(count)
    local slots = {}
    for i = 1, count do slots[i] = false end
    return slots
end

---Turn a database row into the shape the rest of the resource uses: real booleans, real floats.
---@param r table raw row
---@return table
local function toRow(r)
    return {
        id = r.id,
        name = r.name,
        x = r.x + 0.0,
        y = r.y + 0.0,
        z = r.z + 0.0,
        heading = (r.heading or 0) + 0.0,
        count = validCount(r.slots),
        colour = validColour(r.colour),
        enabled = r.enabled == 1 or r.enabled == true,
        slots = emptySlots(validCount(r.slots)),
        createdBy = r.createdBy,
    }
end

---Push the enabled stations and their slot occupancy to every client. A state bag rather than an
---event so late joiners need no resync and a client can rebuild from GlobalState at any time.
local function publish()
    local list = {}
    for _, st in pairs(cache) do
        if st.enabled then
            list[#list + 1] = { id = st.id, name = st.name, x = st.x, y = st.y, z = st.z, heading = st.heading, count = st.count, colour = st.colour, slots = st.slots }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    GlobalState[STATE_KEY] = list
end

---Finite number or nil.
---@param n any
---@return number|nil
local function finite(n)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n + 0.0
end

---Trimmed name inside the column's limits, or nil.
---@param name any
---@return string|nil
local function validName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if #name < 1 or #name > 48 then return nil end
    return name
end

---Load the table, seed it on the very first boot, and publish. Called once from server/main.lua,
---before the scooters boot so they can re-occupy their slots.
function stations.boot()
    local rows = store.stations.all()
    if #rows == 0 and CFG.Seed and #CFG.Seed > 0 then
        for _, s in ipairs(CFG.Seed) do
            store.stations.insert({ name = s.name, x = s.x, y = s.y, z = s.z, heading = s.heading or 0.0, enabled = true, createdBy = 'seed' })
        end
        rows = store.stations.all()
        log.info('stations', 'seeded %d station(s) from config', #rows)
    end
    cache = {}
    for _, r in ipairs(rows) do cache[r.id] = toRow(r) end
    publish()
end

---Every station, sorted by id. Returns copies so callers cannot poke the cache; `occupied` counts
---the taken slots for the panel.
---@return table[]
function stations.all()
    local out = {}
    for _, st in pairs(cache) do
        local copy = {}
        for k, v in pairs(st) do copy[k] = v end
        copy.slots = {}
        copy.occupied = 0
        for i = 1, st.count do
            local s = st.slots[i]
            copy.slots[i] = s and { scooterId = s.scooterId, full = s.full, plate = s.plate, colour = s.colour, battery = s.battery, target = s.target } or false
            if s then copy.occupied = copy.occupied + 1 end
        end
        out[#out + 1] = copy
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---Cached station by id.
---@param id integer
---@return table|nil
function stations.get(id)
    return cache[tonumber(id) or -1]
end

---Names of the enabled stations within `radius` metres of a station, nearest first. Every charger
---screen shows the station closest to the viewer, so stations this close share what they display.
---@param id integer
---@param radius number
---@return string[]
function stations.nearby(id, radius)
    local st = stations.get(id)
    if not st then return {} end
    local near = {}
    for _, other in pairs(cache) do
        if other.id ~= st.id and other.enabled then
            local d = #(vec3(st.x, st.y, st.z) - vec3(other.x, other.y, other.z))
            if d <= radius then near[#near + 1] = { name = other.name, d = d } end
        end
    end
    table.sort(near, function(a, b) return a.d < b.d end)
    for i, n in ipairs(near) do near[i] = ('%s (%.0fm)'):format(n.name, n.d) end
    return near
end

---Number of cached stations.
---@return integer
function stations.count()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end

---World pose of a slot: the docked scooter's origin and heading.
---@param st table station row
---@param slot integer 1..Slots
---@return number x, number y, number z, number heading
function stations.slotPose(st, slot)
    local rad = math.rad(st.heading)
    local ox, oy = CFG.SlotX[slot] or 0.0, CFG.SlotY
    return st.x + ox * math.cos(rad) - oy * math.sin(rad),
           st.y + ox * math.sin(rad) + oy * math.cos(rad),
           st.z + config.Scooters.GroundClearance,
           (st.heading + CFG.SlotHeadingOffset) % 360.0
end

---First free slot of a station, or nil when it is full.
---@param st table station row
---@return integer|nil
function stations.freeSlot(st)
    for i = 1, st.count do
        if not st.slots[i] then return i end
    end
    return nil
end

---The free slot whose dock is closest to a point, so a scooter rolls into the dock it stopped at
---rather than the first one on the rail. nil when the station is full.
---@param st table station row
---@param x number
---@param y number
---@param z number
---@return integer|nil
function stations.nearestFreeSlot(st, x, y, z)
    local at, best, bestD = vector3(x, y, z), nil, math.huge
    for i = 1, st.count do
        if not st.slots[i] then
            local sx, sy, sz = stations.slotPose(st, i)
            local d = #(at - vector3(sx, sy, sz))
            if d < bestD then best, bestD = i, d end
        end
    end
    return best
end

---The enabled station closest to a point within maxDistance, optionally only ones with a free slot.
---@param x number
---@param y number
---@param z number
---@param maxDistance number
---@param needFree boolean|nil
---@return table|nil station
---@return number|nil distance
function stations.nearest(x, y, z, maxDistance, needFree)
    local at = vector3(x, y, z)
    local best, bestD = nil, maxDistance
    for _, st in pairs(cache) do
        if st.enabled and (not needFree or stations.freeSlot(st)) then
            local d = #(at - vector3(st.x, st.y, st.z))
            if d <= bestD then best, bestD = st, d end
        end
    end
    return best, best and bestD or nil
end

---Mark a slot as holding a scooter. In-memory plus publish; the scooter row carries the persisted
---side. `info` is what the station screen shows: plate, colour index and battery percent.
---@param id integer station id
---@param slot integer
---@param scooterId integer
---@param full boolean whether the lens shows green already
---@param info table|nil { plate, colour, battery, target }
---@return boolean ok
function stations.occupy(id, slot, scooterId, full, info)
    local st = stations.get(id)
    if not st or not CFG.SlotX[slot] or slot > st.count then return false end
    info = info or {}
    st.slots[slot] = { scooterId = scooterId, full = full and true or false, plate = info.plate, colour = info.colour, battery = info.battery, target = info.target }
    publish()
    return true
end

---Update the paid charge target the station screen shows for a slot (nil = nothing bought).
---@param id integer station id
---@param slot integer
---@param target integer|nil
function stations.setTarget(id, slot, target)
    local st = stations.get(id)
    local s = st and st.slots[slot]
    if not s or s.target == target then return end
    s.target = target
    publish()
end

---Update the battery the station screen shows for a slot. Publishes only when the value changed.
---@param id integer station id
---@param slot integer
---@param battery integer
function stations.setBattery(id, slot, battery)
    local st = stations.get(id)
    local s = st and st.slots[slot]
    if not s or s.battery == battery then return end
    s.battery = battery
    publish()
end

---Free a slot.
---@param id integer station id
---@param slot integer
function stations.release(id, slot)
    local st = stations.get(id)
    if not st or not st.slots[slot] then return end
    st.slots[slot] = false
    publish()
end

---Flip a slot's lens between charging and full.
---@param id integer station id
---@param slot integer
---@param full boolean
function stations.setFull(id, slot, full)
    local st = stations.get(id)
    if not st or not st.slots[slot] then return end
    if st.slots[slot].full == (full and true or false) then return end
    st.slots[slot].full = full and true or false
    publish()
end

---Create a station from placement data. Validates here, not in the store, so the admin callbacks
---and the export share one rule set.
---@param data table { name, x, y, z, heading, count? }
---@param createdBy string|nil identifier of the admin, 'seed', or another resource's tag
---@return table|false row; false rather than nil so the error survives the export boundary
---@return string|nil errKey locale key when false
function stations.create(data, createdBy)
    local name = validName(data and data.name)
    if not name then return false, 'err.name_length' end
    local x, y, z = finite(data.x), finite(data.y), finite(data.z)
    if not (x and y and z) then return false, 'err.bad_coords' end
    local heading = (finite(data.heading) or 0.0) % 360.0
    local count = validCount(data.count)
    local colour = validColour(data.colour)
    local id = store.stations.insert({ name = name, x = x, y = y, z = z, heading = heading, slots = count, colour = colour, enabled = true, createdBy = createdBy })
    local row = { id = id, name = name, x = x, y = y, z = z, heading = heading, count = count, colour = colour, enabled = true, slots = emptySlots(count), createdBy = createdBy }
    cache[id] = row
    publish()
    log.info('stations', 'created #%d %s at %.1f, %.1f, %.1f with %d dock(s) by %s', id, name, x, y, z, count, tostring(createdBy))
    return row
end

---Move a station (and everything docked in it) to a new pose. The moved listeners run before the
---publish so a client never sees the rail somewhere its scooters are not.
---@param id integer
---@param data table { x, y, z, heading }
---@return boolean ok
---@return string|nil errKey
function stations.move(id, data)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    local x, y, z = finite(data and data.x), finite(data and data.y), finite(data and data.z)
    if not (x and y and z) then return false, 'err.bad_coords' end
    st.x, st.y, st.z, st.heading = x, y, z, (finite(data.heading) or st.heading) % 360.0
    store.stations.setPosition(st.id, st.x, st.y, st.z, st.heading)
    for _, fn in ipairs(movedListeners) do
        local ok, err = pcall(fn, st.id)
        if not ok then log.error('stations', 'onMoved listener failed: %s', tostring(err)) end
    end
    publish()
    log.info('stations', 'moved #%d %s to %.1f, %.1f, %.1f', st.id, st.name, x, y, z)
    return true
end

---Change how many docks a station has. The rail can only be shortened past empty docks: a
---scooter sitting in dock 3 keeps the station at three or more.
---@param id integer
---@param count integer 1..MaxSlots
---@return boolean ok
---@return string|nil errKey
function stations.setCount(id, count)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    count = math.tointeger(tonumber(count) or 0) or 0
    if count < 1 or count > CFG.MaxSlots then return false, 'err.bad_count' end
    for i = count + 1, st.count do
        if st.slots[i] then return false, 'err.dock_in_use' end
    end
    local slots = {}
    for i = 1, count do slots[i] = st.slots[i] or false end
    st.count, st.slots = count, slots
    store.stations.setSlots(st.id, count)
    publish()
    log.info('stations', 'station #%d %s now has %d dock(s)', st.id, st.name, count)
    return true
end

---Rename a station, save it and republish.
---@param id integer
---@param name string
---@return boolean ok
---@return string|nil errKey
function stations.rename(id, name)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    local clean = validName(name)
    if not clean then return false, 'err.name_length' end
    st.name = clean
    store.stations.setName(st.id, clean)
    publish()
    return true
end

---Enable or disable a station, save it and republish.
---@param id integer
---@param enabled boolean
---@return boolean ok
---@return string|nil errKey
function stations.setEnabled(id, enabled)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    st.enabled = enabled and true or false
    store.stations.setEnabled(st.id, st.enabled)
    publish()
    return true
end

---Delete a station and tell the listeners (docked scooters become free-standing). Publishes after
---the listeners ran so a client never sees a scooter still parked in a slot that is gone.
---@param id integer
---@return boolean ok
---@return string|nil errKey
function stations.remove(id)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    cache[st.id] = nil
    store.stations.delete(st.id)
    for _, fn in ipairs(removedListeners) do
        local ok, err = pcall(fn, st.id)
        if not ok then log.error('stations', 'onRemoved listener failed: %s', tostring(err)) end
    end
    publish()
    log.info('stations', 'deleted #%d %s', st.id, st.name)
    return true
end

---Repaint a station. Only the post and totem shells change, so every client swaps two small
---models and keeps the rest of the station streamed.
---@param id integer
---@param colour integer 1..#Colours
---@return boolean ok
---@return string|nil errKey
function stations.setColour(id, colour)
    local st = stations.get(id)
    if not st then return false, 'err.no_station' end
    colour = math.tointeger(tonumber(colour) or 0) or 0
    if colour < 1 or colour > #CFG.Colours then return false, 'err.bad_colour' end
    st.colour = colour
    store.stations.setColour(st.id, colour)
    publish()
    log.info('stations', 'station #%d %s painted %s', st.id, st.name, CFG.Colours[colour].name)
    return true
end

---Register a listener for deletions. Used by the scooters module instead of a require in the
---other direction, which would cycle.
---@param fn fun(id: integer)
function stations.onRemoved(fn)
    removedListeners[#removedListeners + 1] = fn
end

---Register a listener for moves; the scooters module re-pins its docked scooters from it.
---@param fn fun(id: integer)
function stations.onMoved(fn)
    movedListeners[#movedListeners + 1] = fn
end

---Public API for other resources (and the dev probes). Same functions the admin panel uses.
exports('getStations', stations.all)
exports('createStation', stations.create)
exports('renameStation', stations.rename)
exports('setStationEnabled', stations.setEnabled)
exports('deleteStation', stations.remove)
exports('moveStation', stations.move)
exports('setStationSlots', stations.setCount)
exports('setStationColour', stations.setColour)

---Register the module so `require 'server.scoot.stations'` returns this table.
---@return table
package.preload['server.scoot.stations'] = function() return stations end

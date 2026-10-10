---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'

---@type table Bunker tuning (configs/shared/bunkers.lua).
local CFG = config.Bunkers
---@type string GlobalState key the enabled bunkers are published under; clients stream from it.
local STATE_KEY = 'sd_scoot:bunkers'

---@type table Bunkers module; the table returned at end of file.
local bunkers = {}

---@type table<integer, table> Every row by id, enabled or not. The database is only read at boot.
local cache = {}
---@type fun(id: integer)[] Listeners told when a bunker is deleted (scooters detach themselves).
local removedListeners = {}

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
        enabled = r.enabled == 1 or r.enabled == true,
        stock = math.tointeger(tonumber(r.stock) or 0) or 0,
        busy = false,
        createdBy = r.createdBy,
    }
end

---Push the enabled bunkers to every client. A state bag rather than an event so late joiners need
---no resync and a client can rebuild from GlobalState at any time.
local function publish()
    local list = {}
    for _, b in pairs(cache) do
        if b.enabled then
            list[#list + 1] = { id = b.id, name = b.name, x = b.x, y = b.y, z = b.z, heading = b.heading }
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

---Load the table, seed it on the very first boot, and publish. Called once from server/main.lua.
function bunkers.boot()
    local rows = store.bunkers.all()
    if #rows == 0 and CFG.Seed then
        for _, s in ipairs(CFG.Seed) do
            store.bunkers.insert({ name = s.name, x = s.x, y = s.y, z = s.z, heading = s.heading or 0.0, enabled = true, createdBy = 'seed' })
        end
        rows = store.bunkers.all()
        log.info('bunkers', 'seeded %d bunker(s) from config', #rows)
    end
    cache = {}
    for _, r in ipairs(rows) do cache[r.id] = toRow(r) end
    publish()
end

---Every bunker, sorted by id. Returns copies so callers cannot poke the cache.
---@return table[]
function bunkers.all()
    local out = {}
    for _, b in pairs(cache) do
        local copy = {}
        for k, v in pairs(b) do copy[k] = v end
        out[#out + 1] = copy
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---Cached bunker by id.
---@param id integer
---@return table|nil
function bunkers.get(id)
    return cache[tonumber(id) or -1]
end

---Number of cached bunkers.
---@return integer
function bunkers.count()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end

---Create a bunker from placement data. Validates here, not in the store, so the admin callbacks
---and the export share one rule set.
---@param data table { name, x, y, z, heading }
---@param createdBy string|nil identifier of the admin, 'seed', or another resource's tag
---@return table|false row; false rather than nil so the error survives the export boundary
---@return string|nil errKey locale key when false
function bunkers.create(data, createdBy)
    local name = validName(data and data.name)
    if not name then return false, 'err.name_length' end
    local x, y, z = finite(data.x), finite(data.y), finite(data.z)
    if not (x and y and z) then return false, 'err.bad_coords' end
    local heading = (finite(data.heading) or 0.0) % 360.0
    local id = store.bunkers.insert({ name = name, x = x, y = y, z = z, heading = heading, enabled = true, stock = CFG.Stock, createdBy = createdBy })
    local row = { id = id, name = name, x = x, y = y, z = z, heading = heading, enabled = true, stock = CFG.Stock, busy = false, createdBy = createdBy }
    cache[id] = row
    publish()
    log.info('bunkers', 'created #%d %s at %.1f, %.1f, %.1f by %s', id, name, x, y, z, tostring(createdBy))
    return row
end

---Move a bunker to a new pose. Its scooters are free-standing vehicles, so nothing else moves.
---@param id integer
---@param data table { x, y, z, heading }
---@return boolean ok
---@return string|nil errKey
function bunkers.move(id, data)
    local b = bunkers.get(id)
    if not b then return false, 'err.no_bunker' end
    local x, y, z = finite(data and data.x), finite(data and data.y), finite(data and data.z)
    if not (x and y and z) then return false, 'err.bad_coords' end
    b.x, b.y, b.z, b.heading = x, y, z, (finite(data.heading) or b.heading) % 360.0
    store.bunkers.setPosition(b.id, b.x, b.y, b.z, b.heading)
    publish()
    log.info('bunkers', 'moved #%d %s to %.1f, %.1f, %.1f', b.id, b.name, x, y, z)
    return true
end

---Rename a bunker, save it and republish.
---@param id integer
---@param name string
---@return boolean ok
---@return string|nil errKey
function bunkers.rename(id, name)
    local b = bunkers.get(id)
    if not b then return false, 'err.no_bunker' end
    local clean = validName(name)
    if not clean then return false, 'err.name_length' end
    b.name = clean
    store.bunkers.setName(b.id, clean)
    publish()
    return true
end

---Enable or disable a bunker, save it and republish.
---@param id integer
---@param enabled boolean
---@return boolean ok
---@return string|nil errKey
function bunkers.setEnabled(id, enabled)
    local b = bunkers.get(id)
    if not b then return false, 'err.no_bunker' end
    b.enabled = enabled and true or false
    store.bunkers.setEnabled(b.id, b.enabled)
    publish()
    return true
end

---Delete a bunker and tell the listeners (scooters drop their home). Publishes after the listeners
---ran so a client never sees a scooter still pointing at a bunker that is gone.
---@param id integer
---@return boolean ok
---@return string|nil errKey
function bunkers.remove(id)
    local b = bunkers.get(id)
    if not b then return false, 'err.no_bunker' end
    cache[b.id] = nil
    store.bunkers.delete(b.id)
    for _, fn in ipairs(removedListeners) do
        local ok, err = pcall(fn, b.id)
        if not ok then log.error('bunkers', 'onRemoved listener failed: %s', tostring(err)) end
    end
    publish()
    log.info('bunkers', 'deleted #%d %s', b.id, b.name)
    return true
end

---Change a bunker's stock by delta (never below zero), persisted.
---@param id integer
---@param delta integer
---@return integer|nil stock the new stock, nil when the bunker is unknown
function bunkers.adjustStock(id, delta)
    local b = bunkers.get(id)
    if not b then return nil end
    b.stock = math.max(0, (b.stock or 0) + (math.tointeger(delta) or 0))
    store.bunkers.setStock(b.id, b.stock)
    return b.stock
end

---Set a bunker's stock to an exact count (the admin panel), persisted.
---@param id integer
---@param stock integer 0..999
---@return boolean|false ok
---@return string|nil errKey
function bunkers.setStock(id, stock)
    local b = bunkers.get(id)
    if not b then return false, 'err.no_bunker' end
    stock = math.tointeger(tonumber(stock) or -1)
    if not stock or stock < 0 or stock > 999 then return false, 'err.bad_stock' end
    b.stock = stock
    store.bunkers.setStock(b.id, stock)
    return true
end

---Mark a bunker as running (or done with) a dispense cycle. In-memory only.
---@param id integer
---@param busy boolean
function bunkers.setBusy(id, busy)
    local b = bunkers.get(id)
    if b then b.busy = busy and true or false end
end

---Register a listener for deletions. Used by the scooters module instead of a require in the
---other direction, which would cycle (scooters already require bunkers to spawn at one).
---@param fn fun(id: integer)
function bunkers.onRemoved(fn)
    removedListeners[#removedListeners + 1] = fn
end

---Public API for other resources (and the dev probes). Same functions the admin panel uses.
exports('getBunkers', bunkers.all)
exports('createBunker', bunkers.create)
exports('renameBunker', bunkers.rename)
exports('setBunkerEnabled', bunkers.setEnabled)
exports('deleteBunker', bunkers.remove)
exports('adjustBunkerStock', bunkers.adjustStock)
exports('setBunkerStock', bunkers.setStock)

---Register the module so `require 'server.scoot.bunkers'` returns this table.
---@return table
package.preload['server.scoot.bunkers'] = function() return bunkers end

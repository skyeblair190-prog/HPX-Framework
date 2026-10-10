---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Bunker cache (server/scoot/bunkers.lua): the depot a collected scooter can fall back to.
local bunkers = require 'server.scoot.bunkers'
---@type table Station cache + slot bookkeeping (server/scoot/stations.lua).
local stations = require 'server.scoot.stations'
---@type table Scooter fleet (server/scoot/scooters.lua).
local scooters = require 'server.scoot.scooters'

---@type table Battery tuning (configs/shared/battery.lua).
local CFG = config.Battery
---@type table Paid charging tuning (configs/shared/battery.lua > Paid).
local PAID = CFG.Paid or { Enabled = false }

---@type table Battery module; the table returned at end of file.
local battery = {}

---@type fun(entry: table)[] Listeners told when a ride drains its scooter to zero (rentals ends it).
local flatListeners = {}

---Integer percent for a cache entry. Unknown rows count as full so a fleet that predates the
---battery keeps working.
---@param entry table scooters cache entry
---@return integer
function battery.level(entry)
    if not CFG.Enabled then return CFG.FullAt end
    return math.tointeger(math.floor(tonumber(entry.row.battery) or CFG.FullAt)) or CFG.FullAt
end

---Whether a scooter holds enough charge to start a ride.
---@param entry table scooters cache entry
---@return boolean
function battery.canRent(entry)
    if not CFG.Enabled then return true end
    return battery.level(entry) >= CFG.MinToRent
end

---Whether charging must be bought on the station screen.
---@return boolean
function battery.isPaid()
    return CFG.Enabled and PAID.Enabled == true
end

---Price and duration of charging a scooter up to a target percent. The bill is whole currency.
---@param entry table scooters cache entry
---@param target integer
---@return table|false quote { level, target, adds, minutes, cost }
---@return string|nil errKey
function battery.quote(entry, target)
    target = math.tointeger(tonumber(target) or 0) or 0
    local level = battery.level(entry)
    local step = math.max(1, math.tointeger(tonumber(PAID.Step) or 5) or 5)
    if target <= level or target > CFG.FullAt or (target < CFG.FullAt and target % step ~= 0) then return false, 'err.bad_target' end
    local adds = target - level
    local cost = math.max(tonumber(PAID.MinimumFee) or 0, math.ceil(adds * (tonumber(PAID.PricePerPercent) or 0)))
    return { level = level, target = target, adds = adds, minutes = math.ceil(adds / CFG.ChargePerMinute), cost = math.tointeger(math.ceil(cost)) or 0 }
end

---Register a listener for scooters that run flat mid-ride.
---@param fn fun(entry: table)
function battery.onFlat(fn)
    flatListeners[#flatListeners + 1] = fn
end

---Bring a flat scooter back into the fleet: the nearest station with a free slot, else its home
---bunker's stock, else where it stands, full again either way.
---@param entry table scooters cache entry
function battery.collect(entry)
    local r = entry.row
    entry.flatAt = nil
    local st = stations.nearest(r.x, r.y, r.z, math.huge, true)
    if st then
        local slot = stations.freeSlot(st)
        scooters.setBattery(r.id, CFG.FullAt)
        scooters.dock(r.id, st.id, slot)
        stations.occupy(st.id, slot, r.id, true, { plate = r.plate, colour = r.colour, battery = CFG.FullAt })
        log.info('battery', 'collected flat %s into %s slot %d', r.plate, st.name, slot)
        return
    end
    local home = r.bunkerId and bunkers.get(r.bunkerId) or nil
    if home then
        scooters.remove(r.id)
        bunkers.adjustStock(home.id, 1)
        log.info('battery', 'collected flat %s back into bunker %s', r.plate, home.name)
        return
    end
    scooters.setBattery(r.id, CFG.FullAt)
    scooters.undock(r.id)
    log.info('battery', 'collected flat %s where it stood (no station or bunker)', r.plate)
end

---One tick: drain rides, charge docked scooters, collect stale flat ones.
local function tick()
    local perTick = CFG.TickSeconds / 60
    for _, entry in pairs(scooters.entries()) do
        local r = entry.row
        if r.status == 'rented' then
            local next = math.max(0, battery.level(entry) - CFG.DrainPerMinute * perTick)
            scooters.setBattery(r.id, next)
            if next <= 0 then
                for _, fn in ipairs(flatListeners) do
                    local ok, err = pcall(fn, entry)
                    if not ok then log.error('battery', 'onFlat listener failed: %s', tostring(err)) end
                end
            end
        elseif r.status == 'charging' and r.stationId and (not PAID.Enabled or r.chargeTarget) then
            local before = battery.level(entry)
            local cap = PAID.Enabled and math.min(CFG.FullAt, r.chargeTarget) or CFG.FullAt
            local next = math.min(cap, before + CFG.ChargePerMinute * perTick)
            if next ~= before then
                scooters.setBattery(r.id, next)
                stations.setBattery(r.stationId, r.slot, battery.level(entry))
            end
            if before < CFG.FullAt and next >= CFG.FullAt then stations.setFull(r.stationId, r.slot, true) end
            if PAID.Enabled and next >= cap then
                scooters.setChargeTarget(r.id, nil)
                stations.setTarget(r.stationId, r.slot, nil)
            end
        elseif r.status == 'flat' and entry.flatAt and os.time() - entry.flatAt >= CFG.FlatRecoverMinutes * 60 then
            battery.collect(entry)
        end
    end
end

---Start the tick loop. Called once from server/main.lua after the fleet and rentals booted.
function battery.boot()
    if not CFG.Enabled then return end
    local every = math.max(10, math.min(300, math.tointeger(tonumber(CFG.TickSeconds) or 60) or 60))
    CreateThread(function()
        while true do
            Wait(every * 1000)
            local ok, err = pcall(tick)
            if not ok then log.error('battery', 'tick failed: %s', tostring(err)) end
        end
    end)
end

---Battery percent of a fleet scooter for other resources; nil when the id is unknown.
---@param id integer scooter id
---@return integer|nil
exports('getScooterBattery', function(id)
    local entry = scooters.get(id)
    return entry and battery.level(entry) or nil
end)

---Register the module so `require 'server.scoot.battery'` returns this table.
---@return table
package.preload['server.scoot.battery'] = function() return battery end

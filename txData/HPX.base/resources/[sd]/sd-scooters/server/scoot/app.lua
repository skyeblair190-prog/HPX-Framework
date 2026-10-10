---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Rides, billing and idle locks (server/scoot/rentals.lua).
local rentals = require 'server.scoot.rentals'

---@type table Rental tuning (configs/shared/rentals.lua).
local CFG = config.Rentals

---Failure reply with a localised message.
---@param errKey string
---@return table
local function fail(errKey)
    return { success = false, message = locale(errKey) }
end

---Register one phone-app callback. Handler errors become a generic failure rather than a dead
---request; the app is disabled outright when rentals are off.
---@param verb string callback suffix (sd_scoot:server:app:<verb>)
---@param fn fun(src: integer, data: table): table
local function register(verb, fn)
    lib.callback.register('sd_scoot:server:app:' .. verb, function(src, data)
        if not CFG.Enabled then return fail('err.app_disabled') end
        local okay, reply = pcall(fn, src, type(data) == 'table' and data or {})
        if not okay then
            log.error('app', '%s failed for %s: %s', verb, tostring(src), tostring(reply))
            return fail('ui.toast.failed')
        end
        return reply
    end)
end

---Nearby-scooters snapshot for the app's map and list.
---@param src integer
---@return table reply { success, data = nearby snapshot }
register('nearby', function(src)
    return { success = true, data = rentals.nearby(src) }
end)

---Rent a scooter dispensed from a bunker, with the chosen colour and customisation.
---@param src integer
---@param data table { bunkerId, colour, customization }
---@return table reply { success, data = { dispense, nearby } } or a localised failure
register('rentHere', function(src, data)
    local dispense, err = rentals.rentAtBunker(src, tonumber(data.bunkerId) or -1, data.colour, data.customization)
    if not dispense then return fail(err) end
    return { success = true, data = { dispense = dispense, nearby = rentals.nearby(src) } }
end)

---End the caller's ride and bill it, returning the receipt plus a refreshed snapshot.
---@param src integer
---@return table reply { success, data = { receipt, nearby } } or a localised failure
register('finish', function(src)
    local receipt, err = rentals.finish(src)
    if not receipt then return fail(err) end
    return { success = true, data = { receipt = receipt, nearby = rentals.nearby(src) } }
end)

---The caller's past rides for the app's history tab.
---@param src integer
---@return table reply { success, data = { rides } }
register('history', function(src)
    return { success = true, data = { rides = rentals.history(src) } }
end)

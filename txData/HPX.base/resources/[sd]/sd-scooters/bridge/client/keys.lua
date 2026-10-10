---Client half of bridge/server/keys.lua. A few key scripts only hand out or take back keys for the
---player who triggered the call, so the server asks the renter's own client to make it.

---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'

---@type table<string, table<string, fun(plate: string, netId: integer|nil, model: string|nil)>>
local CALLS = {
    p_vehiclekeys = {
        give = function(plate, netId)
            if not netId or not NetworkDoesNetworkIdExist(netId) then return end
            exports.p_vehiclekeys:createKey(plate, NetToVeh(netId))
        end,
        remove = function(plate, netId)
            local vehicle = netId and NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
            exports.p_vehiclekeys:removeKey(plate, vehicle, true)
        end,
    },
    okokGarage = {
        give = function(plate) TriggerServerEvent('okokGarage:GiveKeys', plate) end,
    },
    t1ger_keys = {
        give = function(plate, _, model) exports.t1ger_keys:GiveTemporaryKeys(plate, model, 'rental') end,
        remove = function(plate, _, model) TriggerServerEvent('t1ger_keys:deleteCarKeys', plate, model) end,
    },
}

---Run the key script call the server picked, if that script is started here; a failure is logged, not thrown.
---@param resource string key script the server resolved
---@param action 'give'|'remove'
---@param plate string trimmed plate
---@param netId integer|nil
---@param model string|nil vehicle display name
RegisterNetEvent('sd_scoot:client:keys', function(resource, action, plate, netId, model)
    local call = CALLS[resource] and CALLS[resource][action]
    if not call or GetResourceState(resource) ~= 'started' then return end
    local ok, err = pcall(call, plate, netId, model)
    if not ok then log.warn('keys', '%s %s failed: %s', resource, action, tostring(err)) end
end)

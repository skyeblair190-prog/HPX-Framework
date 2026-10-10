---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'

---@type table Vehicle key + lock helper module returned to consumers.
local keys = {}

---@type string Client event that runs a key call on the renter's own client, for key scripts whose
---give/remove only act on the player who triggered them (bridge/client/keys.lua).
local RELAY_EVENT = 'sd_scoot:client:keys'

---@class KeyAdapter
---@field resource string resource folder name checked with GetResourceState
---@field give fun(source: number, vehicle: integer, plate: string)
---@field remove fun(source: number, vehicle: integer, plate: string)|nil nil when the script has no way to take a key back

---Every supported key script, in detection order. Scripts that `provide` another script's name, or
---register look-alike exports under it (qbx_vehiclekeys, p_vehiclekeys, ak47_vehiclekeys), come
---before the names they imitate, so the real owner is always the one called.
---Each call was checked against the script's own source or official docs (2026-09-17).
---@type KeyAdapter[]
local ADAPTERS = {
    { -- Qbox; keyed by entity. Third arg skips the "keys received / removed" notification.
        resource = 'qbx_vehiclekeys',
        give = function(src, vehicle) exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true) end,
        remove = function(src, vehicle) exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true) end,
    },
    { -- PiotreeQ; client exports only (createKey needs the networked entity).
        resource = 'p_vehiclekeys',
        give = function(src, vehicle, plate) TriggerClientEvent(RELAY_EVENT, src, 'p_vehiclekeys', 'give', plate, NetworkGetNetworkIdFromEntity(vehicle)) end,
        remove = function(src, vehicle, plate) TriggerClientEvent(RELAY_EVENT, src, 'p_vehiclekeys', 'remove', plate, NetworkGetNetworkIdFromEntity(vehicle)) end,
    },
    { -- MenanAK47 multi-framework; virtual keys are the no-item keys the docs suggest for rentals.
        resource = 'ak47_vehiclekeys',
        give = function(src, _, plate) exports.ak47_vehiclekeys:GiveVirtualKey(src, plate) end,
        remove = function(src, _, plate) exports.ak47_vehiclekeys:RemoveVirtualKey(src, plate) end,
    },
    { -- MenanAK47 QBCore edition; `true` marks a vehicle nobody owns.
        resource = 'ak47_qb_vehiclekeys',
        give = function(src, _, plate) exports.ak47_qb_vehiclekeys:GiveKey(src, plate, true) end,
        remove = function(src, _, plate) exports.ak47_qb_vehiclekeys:RemoveKey(src, plate, true) end,
    },
    { -- MrNewb; the netId variant avoids any plate formatting mismatch.
        resource = 'MrNewbVehicleKeys',
        give = function(src, vehicle) exports.MrNewbVehicleKeys:GiveKeys(src, NetworkGetNetworkIdFromEntity(vehicle)) end,
        remove = function(src, vehicle) exports.MrNewbVehicleKeys:RemoveKeys(src, NetworkGetNetworkIdFromEntity(vehicle)) end,
    },
    {
        resource = 'Renewed-Vehiclekeys',
        give = function(src, _, plate) exports['Renewed-Vehiclekeys']:addKey(src, plate) end,
        remove = function(src, _, plate) exports['Renewed-Vehiclekeys']:removeKey(src, plate) end,
    },
    { -- Jaksam
        resource = 'vehicles_keys',
        give = function(src, _, plate) exports.vehicles_keys:giveVehicleKeysToPlayerId(src, plate, 'temporary') end,
        remove = function(src, _, plate) exports.vehicles_keys:removeKeysFromPlayerId(src, plate) end,
    },
    { -- ManKind; vehicle first, player second.
        resource = 'mk_vehiclekeys',
        give = function(src, vehicle) exports.mk_vehiclekeys:AddKey(vehicle, src) end,
        remove = function(src, vehicle) exports.mk_vehiclekeys:RemoveKey(vehicle, src) end,
    },
    { -- 0Resmon
        resource = '0r-vehiclekeys',
        give = function(src, _, plate) exports['0r-vehiclekeys']:GiveKeys(src, plate) end,
        remove = function(src, _, plate) exports['0r-vehiclekeys']:RemoveKeys(src, plate) end,
    },
    { -- One export for both: the last argument is give (true) or take (false).
        resource = 'fivecode_carkeys',
        give = function(src, vehicle, plate) exports.fivecode_carkeys:GiveKey(src, { vehicle = vehicle, plate = plate, model = keys.displayName() }, false, true) end,
        remove = function(src, vehicle, plate) exports.fivecode_carkeys:GiveKey(src, { vehicle = vehicle, plate = plate, model = keys.displayName() }, false, false) end,
    },
    { -- Mono; temporary vehicles clear themselves when the entity is deleted, there is no remove call.
        resource = 'mVehicle',
        give = function(src, vehicle) exports.mVehicle:AddTemporalVehicle(src, vehicle) end,
    },
    { -- A realistic key system: the docs state there is deliberately no remove export.
        resource = 'tgiann-hotwire',
        give = function(src, _, plate) exports['tgiann-hotwire']:GiveKeyPlate(src, plate, false) end,
    },
    { -- No documented remove for vehicle keys, so a temporary key that outlives the longest ride.
        resource = 'brutal_keys',
        give = function(src, _, plate)
            TriggerEvent('brutal_keys:server:addVehicleTemporaryKey', src, (tonumber(config.Rentals.MaxRideMinutes) or 180) * 60, plate, plate)
        end,
    },
    { -- Codesign; client events keyed by plate.
        resource = 'cd_garage',
        give = function(src, _, plate) TriggerClientEvent('cd_garage:AddKeys', src, plate) end,
        remove = function(src, _, plate) TriggerClientEvent('cd_garage:RemoveKeys', src, plate) end,
    },
    { -- Its give event reads the triggering player, so it has to come from the renter's client.
        resource = 'okokGarage',
        give = function(src, _, plate) TriggerClientEvent(RELAY_EVENT, src, 'okokGarage', 'give', plate) end,
        remove = function(src, _, plate) TriggerEvent('okokGarage:RemoveKeys', plate, src) end,
    },
    { -- ESX; temporary keys are client-driven, both ways.
        resource = 't1ger_keys',
        give = function(src, _, plate) TriggerClientEvent(RELAY_EVENT, src, 't1ger_keys', 'give', plate, nil, keys.displayName()) end,
        remove = function(src, _, plate) TriggerClientEvent(RELAY_EVENT, src, 't1ger_keys', 'remove', plate, nil, keys.displayName()) end,
    },
    { -- Quasar; the model is the vehicle's display name (gameName in data/vehicles.meta).
        resource = 'qs-vehiclekeys',
        give = function(src, _, plate) exports['qs-vehiclekeys']:GiveServerKeys(src, plate, keys.displayName(), false) end,
        remove = function(src, _, plate) exports['qs-vehiclekeys']:RemoveServerKeys(src, plate, keys.displayName()) end,
    },
    {
        resource = 'wasabi_carlock',
        give = function(src, _, plate) exports.wasabi_carlock:GiveKey(src, plate) end,
        remove = function(src, _, plate) exports.wasabi_carlock:RemoveKey(src, plate) end,
    },
    { -- Last: qbx_vehiclekeys, ak47_vehiclekeys and p_vehiclekeys all answer to this name.
        resource = 'qb-vehiclekeys',
        give = function(src, _, plate) exports['qb-vehiclekeys']:GiveKeys(src, plate) end,
        remove = function(src, _, plate) exports['qb-vehiclekeys']:RemoveKeys(src, plate) end,
    },
}

---@type table<string, KeyAdapter>
local byResource = {}
for _, adapter in ipairs(ADAPTERS) do byResource[adapter.resource] = adapter end

---The scooter's display name as GetDisplayNameFromVehicleModel reports it on a client (the server has
---no such native); gameName in data/vehicles.meta is the model name in capitals.
---@return string
function keys.displayName()
    return tostring(config.Scooters.Model):upper()
end

---@type table<string, boolean> config problems already reported, so a bad value warns once, not per ride
local warned = {}

---The key script in use: `Config.VehicleKeys` when set to a resource name, otherwise the first started
---resource in ADAPTERS. Checked on every call so a key script started after this resource is picked up.
---@return KeyAdapter|nil
local function active()
    local choice = config.VehicleKeys
    if choice == 'none' or choice == false then return nil end
    if type(choice) == 'string' and choice ~= 'auto' then
        local adapter = byResource[choice]
        if not adapter then
            if not warned[choice] then
                warned[choice] = true
                log.warn('keys', 'Config.VehicleKeys "%s" is not a supported key script; no keys will be handed out', choice)
            end
            return nil
        end
        if GetResourceState(choice) ~= 'started' then
            if not warned[choice] then
                warned[choice] = true
                log.warn('keys', 'Config.VehicleKeys is "%s" but that resource is not started; no keys will be handed out', choice)
            end
            return nil
        end
        return adapter
    end
    for _, adapter in ipairs(ADAPTERS) do
        if GetResourceState(adapter.resource) == 'started' then return adapter end
    end
    return nil
end

---The vehicle's plate without the padding GTA adds.
---@param vehicle integer
---@return string
local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$')
end

---Run one adapter call, so a key script that changed its API logs a warning instead of breaking the ride.
---@param adapter KeyAdapter
---@param action 'give'|'remove'
---@param source number
---@param vehicle integer
local function run(adapter, action, source, vehicle)
    local fn = adapter[action]
    if not fn or not DoesEntityExist(vehicle) then return end
    local ok, err = pcall(fn, source, vehicle, plateOf(vehicle))
    if not ok then log.warn('keys', '%s %s failed: %s', adapter.resource, action, tostring(err)) end
end

---Lock or unlock a fleet vehicle for everyone. The `doorslockstate` state bag is what
---qbx_vehiclekeys applies on clients; the native covers servers without it.
---@param vehicle integer entity handle
---@param locked boolean
function keys.setLocked(vehicle, locked)
    if not DoesEntityExist(vehicle) then return end
    Entity(vehicle).state:set('doorslockstate', locked and 2 or 1, true)
    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
end

---Hand a player the keys to a vehicle through whichever key script is running (no-op without one:
---the rented vehicle is unlocked in that case anyway).
---@param source number
---@param vehicle integer
function keys.give(source, vehicle)
    local adapter = active()
    if adapter then run(adapter, 'give', source, vehicle) end
end

---Take a player's keys back. Key scripts with no remove call (mVehicle, tgiann-hotwire, brutal_keys)
---leave the key in place until it expires or the vehicle is deleted.
---@param source number
---@param vehicle integer
function keys.remove(source, vehicle)
    local adapter = active()
    if adapter then run(adapter, 'remove', source, vehicle) end
end

return keys

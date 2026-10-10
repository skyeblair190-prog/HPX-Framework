---Storage box, worked like a car trunk: "Open storage" lifts the lid and opens the stash, and
---closing the stash drops the lid shut. Also the renter-only access check and the rental marker the
---client reads to decide whether to offer the option at all.
local config = require 'configs.config'
local log = require 'shared.log'
local extras = require 'shared.extras'
local scooters = require 'server.scoot.scooters'
local rentals = require 'server.scoot.rentals'
local playerMod = require 'bridge.server.player'
local inventory = require 'bridge.server.inventory'

local CFG = config.Storage
local MODEL = joaat(config.Scooters.Model)
---@type string Replicated entity state: true while the lid is open.
local LID_KEY = 'sd_scoot_lid'
---@type string Replicated player state: the scooter id this player is renting, or nil.
local RIDER_KEY = 'sd_scoot_rental'
---@type string Lua pattern for box stash ids; the scooter id is the capture.
local STASH_PATTERN = '^sd_scoot_box_(%d+)$'
---@type integer ms between the lid starting to lift and the stash appearing, so the box is seen opening first
local STASH_DELAY = 450

---@class OpenBox
---@field entity integer the scooter
---@field source integer the player looking inside

---@type table<integer, OpenBox> scooter id -> the open box
local open = {}
---@type table<integer, integer> server id -> scooter id, as last written to player state
local marked = {}
---@type string Replicated player state: true for staff who may open any box (Storage.AdminAccess).
local ADMIN_KEY = 'sd_scoot_box_admin'
---@type string The admin panel's edit ace (server/scoot/admin.lua grants it to Admin.Group).
local EDIT_ACE = config.Admin.EditAce or 'sd_scoot.edit'
---@type table<integer, boolean> server id -> admin flag, as last written to player state
local admins = {}

---Staff with the panel's edit permission open any box when Storage.AdminAccess is on.
---@param source number
---@return boolean
local function isAdmin(source)
    local allowed = IsPlayerAceAllowed(source, EDIT_ACE)
    return CFG.AdminAccess == true and (allowed == true or allowed == 1)
end

---Inventory stash id for a scooter's box.
---@param scooterId integer
---@return string
local function stashId(scooterId) return ('sd_scoot_box_%d'):format(scooterId) end

---Whether a scooter is fitted with the delivery box.
---@param entry table scooters cache entry
---@return boolean
local function hasBox(entry)
    return extras.decode(entry.row.customization).rear == 'delivery'
end

---Shut a box: drop the lid for everyone and close the stash if its viewer still has it up.
---@param scooterId integer
---@param closeStash boolean
local function shut(scooterId, closeStash)
    local box = open[scooterId]
    if not box then return end
    open[scooterId] = nil
    if DoesEntityExist(box.entity) then Entity(box.entity).state:set(LID_KEY, nil, true) end
    if closeStash and GetPlayerPed(box.source) ~= 0 then inventory.close(box.source) end
end

---Is this player renting the scooter (or staff, see isAdmin) and standing at it?
---@param source number
---@param entry table
---@param slack number extra metres on top of Storage.Distance
---@return boolean
---@return string|nil errKey
local function renterAt(source, entry, slack)
    local id = playerMod.getIdentifier(source)
    if not isAdmin(source) and (not id or rentals.renterOf(entry.row.id) ~= id) then return false, 'err.box_not_yours' end
    local ped, v = GetPlayerPed(source), entry.entity
    if ped == 0 or not v or not DoesEntityExist(v) then return false, 'err.no_scooter' end
    if #(GetEntityCoords(ped) - GetEntityCoords(v)) > CFG.Distance + slack then return false, 'err.box_too_far' end
    return true
end

---Stash access check for the inventory hooks: the lid is open for this player, who still rents
---the scooter and stands at it.
---@param source number
---@param id string stash id
---@return boolean
local function allowed(source, id)
    local scooterId = tonumber(tostring(id):match(STASH_PATTERN))
    local box = scooterId and open[scooterId]
    local entry = box and scooters.get(scooterId)
    if not entry or box.source ~= source then return false end
    return (renterAt(source, entry, 2.5))
end

---Resolve a client-sent net id to a boxed scooter this player may open from where they stand.
---@param source number
---@param netId any
---@return table|false entry
---@return string|nil errKey
local function boxFor(source, netId)
    if type(netId) ~= 'number' or netId % 1 ~= 0 or netId < 1 then return false, 'err.no_scooter' end
    local v = NetworkGetEntityFromNetworkId(netId)
    if v == 0 or not DoesEntityExist(v) or GetEntityModel(v) ~= MODEL then return false, 'err.no_scooter' end
    local state = Entity(v).state.sd_scoot
    local entry = state and scooters.get(state.id)
    if not entry or entry.entity ~= v then return false, 'err.no_scooter' end
    if not hasBox(entry) then return false, 'err.no_box' end
    local ok, err = renterAt(source, entry, 1.5)
    if not ok then return false, err end
    return entry
end

---Open storage: lift the lid, then open the stash once the lid is on its way up.
---@param source number
---@param netId integer
---@return boolean ok
---@return string|nil errKey
lib.callback.register('sd_scoot:server:storage', function(source, netId)
    if not CFG.Enabled then return false, 'err.not_allowed' end
    local entry, err = boxFor(source, netId)
    if not entry then return false, err end
    local v, id = entry.entity, entry.row.id
    if GetPedInVehicleSeat(v, -1) ~= 0 or GetEntitySpeed(v) > 1.0 then return false, 'err.box_moving' end
    if not inventory.name() then return false, 'err.no_inventory' end
    local box = open[id]
    if box and box.source ~= source and GetPlayerPed(box.source) ~= 0 then return false, 'err.box_busy' end
    open[id] = { entity = v, source = source }
    Entity(v).state:set(LID_KEY, true, true)
    SetTimeout(box and 0 or STASH_DELAY, function()
        local current = open[id]
        if not current or current.source ~= source then return end
        if not inventory.open(source, stashId(id)) then shut(id, false) end
    end)
    return true
end)

---Closing the stash closes the trunk.
inventory.onClosed(function(source, id)
    local scooterId = tonumber(tostring(id):match(STASH_PATTERN))
    local box = scooterId and open[scooterId]
    if box and box.source == source then shut(scooterId, false) end
end)

---Rental markers and lid upkeep. A lid also shuts when its scooter is ridden off, despawns, loses the
---box, or the player looking inside walks away, stops renting it or leaves.
CreateThread(function()
    for _, entry in pairs(scooters.entries()) do
        if entry.entity and DoesEntityExist(entry.entity) and Entity(entry.entity).state[LID_KEY] then
            Entity(entry.entity).state:set(LID_KEY, nil, true)
        end
    end
    local tick = 0
    while true do
        local riders = rentals.riders()
        for src, scooterId in pairs(riders) do
            if marked[src] ~= scooterId then Player(src).state:set(RIDER_KEY, scooterId, true); marked[src] = scooterId end
        end
        for src in pairs(marked) do
            if not riders[src] then
                if GetPlayerPed(src) ~= 0 then Player(src).state:set(RIDER_KEY, nil, true) end
                marked[src] = nil
            end
        end
        tick = tick + 1
        if tick % 10 == 1 then
            for _, id in ipairs(GetPlayers()) do
                local src = tonumber(id)
                local admin = isAdmin(src)
                if admins[src] ~= admin then Player(src).state:set(ADMIN_KEY, admin or nil, true); admins[src] = admin end
            end
        end
        for scooterId, box in pairs(open) do
            local entry, v = scooters.get(scooterId), box.entity
            local ped = GetPlayerPed(box.source)
            if not entry or entry.entity ~= v or not DoesEntityExist(v) or not hasBox(entry)
                or GetPedInVehicleSeat(v, -1) ~= 0 or GetEntitySpeed(v) > 1.5
                or ped == 0 or (riders[box.source] ~= scooterId and not isAdmin(box.source))
                or #(GetEntityCoords(ped) - GetEntityCoords(v)) > CFG.AutoCloseDistance then
                shut(scooterId, true)
            end
        end
        Wait(500)
    end
end)

---Guard every scooter box stash with the access check, through whichever inventory is running.
local function installHooks()
    inventory.guard('^sd_scoot_box_%d+$', allowed)
end

---Install the stash hooks one tick after boot and log which inventory the boxes will use.
CreateThread(function()
    Wait(0)
    installHooks()
    log.info('storage', 'storage box stash: %s', inventory.name() or 'no supported inventory running')
end)

---Re-install the stash hooks when a supported inventory starts after this resource.
---@param resource string
AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' or resource == 'qb-inventory' then SetTimeout(500, installHooks) end
end)

---Tell the inventory bridge a resource stopped so its hooks are installed again when it returns.
---@param resource string
AddEventHandler('onResourceStop', function(resource)
    inventory.stopped(resource)
end)

---Forget the rider and admin flags last written for a player who left.
AddEventHandler('playerDropped', function()
    marked[source], admins[source] = nil, nil
end)

---Register the module so `require 'server.scoot.storage'` returns the stash access check.
---@return table { allowed }
package.preload['server.scoot.storage'] = function() return { allowed = allowed } end

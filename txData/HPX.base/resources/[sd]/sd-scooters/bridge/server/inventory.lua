---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'

---@type table Delivery-box stash helper module returned to consumers.
local inventory = {}

---@class InventoryAdapter
---@field resource string resource folder name checked with GetResourceState
---@field open fun(source: number, stashId: string, label: string, slots: integer, maxWeight: integer): boolean opened
---@field close fun(source: number)|nil
---@field guard fun(pattern: string, allowed: fun(source: number, stashId: string): boolean)|nil server-side hooks that refuse opening or moving items when `allowed` says no

---@type table<string, boolean> stash ids already registered with ox_inventory this session
local registered = {}

---Supported inventories, in detection order. Each call was checked against the script's own source (2026-09-17).
---@type InventoryAdapter[]
local ADAPTERS = {
    { -- Overextended. The stash is registered once, then force-opened server-side; the hooks below
      -- also cover a client that calls openInventory('stash', id) itself.
        resource = 'ox_inventory',
        open = function(src, stashId, label, slots, maxWeight)
            if not registered[stashId] then
                exports.ox_inventory:RegisterStash(stashId, label, slots, maxWeight)
                registered[stashId] = true
            end
            return exports.ox_inventory:forceOpenInventory(src, 'stash', stashId) ~= nil
        end,
        close = function(src) TriggerClientEvent('sd_scoot:client:storage:closeInventory', src) end,
        guard = function(pattern, allowed)
            local filter = { inventoryFilter = { pattern } }
            exports.ox_inventory:registerHook('openInventory', function(payload)
                return allowed(payload.source, payload.inventoryId)
            end, filter)
            exports.ox_inventory:registerHook('swapItems', function(payload)
                local from, to = payload.fromInventory, payload.toInventory
                if type(from) == 'string' and from:match(pattern) then return allowed(payload.source, from) end
                if type(to) == 'string' and to:match(pattern) then return allowed(payload.source, to) end
                return true
            end, filter)
        end,
    },
    { -- qb-inventory 2.x: OpenInventory creates the stash on first use. It has no hooks, so access is
      -- only checked when the box is opened.
        resource = 'qb-inventory',
        open = function(src, stashId, label, slots, maxWeight)
            exports['qb-inventory']:OpenInventory(src, stashId, { label = label, slots = slots, maxweight = maxWeight })
            return true
        end,
    },
}

---@type table<string, InventoryAdapter>
local byResource = {}
for _, adapter in ipairs(ADAPTERS) do byResource[adapter.resource] = adapter end

---@type table<string, boolean> config problems already reported
local warned = {}

---The inventory in use: `Storage.Inventory` when set to a resource name, otherwise the first started one.
---@return InventoryAdapter|nil
local function active()
    local choice = config.Storage.Inventory
    if type(choice) == 'string' and choice ~= 'auto' then
        local adapter = byResource[choice]
        if not adapter or GetResourceState(choice) ~= 'started' then
            if not warned[choice] then
                warned[choice] = true
                log.warn('storage', 'Storage.Inventory "%s" is not a supported, started inventory; storage boxes have no stash', choice)
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

---Resource name of the active inventory adapter, or nil when none is running.
---@return string|nil resource name of the inventory boxes use
function inventory.name()
    local adapter = active()
    return adapter and adapter.resource or nil
end

---Open a box stash for one player.
---@param source number
---@param stashId string
---@return boolean opened
function inventory.open(source, stashId)
    local adapter = active()
    if not adapter then return false end
    local S = config.Storage
    local ok, opened = pcall(adapter.open, source, stashId, S.Label, S.Slots, S.MaxWeight)
    if not ok then log.warn('storage', '%s open failed: %s', adapter.resource, tostring(opened)) end
    return ok and opened == true
end

---Call `cb` whenever a player closes a stash, whichever supported inventory closed it.
---ox_inventory raises a server event for every close (the player's own, a forced one, walking off);
---qb-inventory 2.x sends its close from the player's client.
---@param cb fun(source: number, stashId: string)
function inventory.onClosed(cb)
    AddEventHandler('ox_inventory:closedInventory', function(playerId, inventoryId)
        if type(inventoryId) == 'string' then cb(playerId, inventoryId) end
    end)
    RegisterNetEvent('qb-inventory:server:closeInventory', function(inventoryId)
        if type(inventoryId) == 'string' then cb(source, inventoryId) end
    end)
end

---Close whatever inventory the player has open (only where the inventory supports it).
---@param source number
function inventory.close(source)
    local adapter = active()
    if adapter and adapter.close then pcall(adapter.close, source) end
end

---@type table<string, boolean> inventories the access hooks were installed in
local guarded = {}

---Install the access hooks in the running inventory, once per inventory start.
---@param pattern string Lua pattern matching box stash ids
---@param allowed fun(source: number, stashId: string): boolean
function inventory.guard(pattern, allowed)
    local adapter = active()
    if not adapter or not adapter.guard or guarded[adapter.resource] then return end
    local ok, err = pcall(adapter.guard, pattern, allowed)
    if ok then guarded[adapter.resource] = true else log.warn('storage', '%s hooks failed: %s', adapter.resource, tostring(err)) end
end

---Forget installed hooks when the inventory stops (they die with it).
---@param resource string
function inventory.stopped(resource)
    guarded[resource] = nil
    if resource == 'ox_inventory' then registered = {} end
end

return inventory

local frameworkName
local inventoryName
local QBCore
local ESX

local framework = function()
    if frameworkName then return frameworkName end
    local set = Config.Framework or 'auto'
    if set == 'auto' then
        if GetResourceState('hpx_core') == 'started' then
            set = 'hpx'
        elseif GetResourceState('qbx_core') == 'started' then
            set = 'qbx'
        elseif GetResourceState('qb-core') == 'started' then
            set = 'qb'
        elseif GetResourceState('es_extended') == 'started' then
            set = 'esx'
        else
            set = 'none'
        end
    end
    frameworkName = set
    if set == 'qb' and not QBCore then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif set == 'esx' and not ESX then
        ESX = exports['es_extended']:getSharedObject()
    end
    return frameworkName
end

local inventory = function()
    if inventoryName then return inventoryName end
    local set = Config.Inventory or 'auto'
    if set == 'auto' then
        if GetResourceState('ox_inventory') == 'started' then
            set = 'ox'
        elseif GetResourceState('qb-inventory') == 'started' then
            set = 'qb'
        elseif framework() == 'esx' then
            set = 'esx'
        else
            set = 'none'
        end
    end
    inventoryName = set
    if set == 'esx' then framework() end
    if set == 'qb' then framework() end
    return inventoryName
end

local corePlayer = function(src)
    local fw = framework()
    if fw == 'qbx' then
        return exports.qbx_core:GetPlayer(src)
    end
    if fw == 'qb' then
        if not QBCore then QBCore = exports['qb-core']:GetCoreObject() end
        return QBCore.Functions.GetPlayer(src)
    end
end

local esxPlayer = function(src)
    framework()
    if not ESX then return end
    return ESX.GetPlayerFromId(src)
end

local moneyOf = function(src, account)
    local fw = framework()
    account = account or 'cash'
    if fw == 'hpx' then
        return exports.hpx_core:GetMoney(src, account)
    end
    if fw == 'qbx' or fw == 'qb' then
        local player = corePlayer(src)
        if not player then return nil end
        return player.Functions.GetMoney(account)
    end
    if fw == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return nil end
        if account == 'cash' or account == 'money' then
            return xPlayer.getMoney()
        end
        local data = xPlayer.getAccount(account)
        return data and data.money or 0
    end
end

local takeMoney = function(src, account, amount)
    local fw = framework()
    account = account or 'cash'
    if fw == 'hpx' then
        return exports.hpx_core:RemoveMoney(src, account, amount, 'hasib_peddialog') == true
    end
    if fw == 'qbx' or fw == 'qb' then
        local player = corePlayer(src)
        if not player then return false end
        return player.Functions.RemoveMoney(account, amount, 'hasib_peddialog')
    end
    if fw == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        if account == 'cash' or account == 'money' then
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount)
            return true
        end
        local data = xPlayer.getAccount(account)
        if not data or data.money < amount then return false end
        xPlayer.removeAccountMoney(account, amount)
        return true
    end
    return false
end

local giveMoney = function(src, account, amount)
    local fw = framework()
    account = account or 'cash'
    if fw == 'hpx' then
        return exports.hpx_core:AddMoney(src, account, amount, 'hasib_peddialog') == true
    end
    if fw == 'qbx' or fw == 'qb' then
        local player = corePlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, 'hasib_peddialog')
    end
    if fw == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        if account == 'cash' or account == 'money' then
            xPlayer.addMoney(amount)
            return true
        end
        xPlayer.addAccountMoney(account, amount)
        return true
    end
    return false
end

local itemCount = function(src, item)
    local inv = inventory()
    if inv == 'ox' then
        return exports.ox_inventory:GetItemCount(src, item) or 0
    end
    if inv == 'qb' then
        local player = corePlayer(src)
        if not player then return 0 end
        local data = player.Functions.GetItemByName(item)
        return data and (data.amount or data.count) or 0
    end
    if inv == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return 0 end
        local data = xPlayer.getInventoryItem(item)
        return data and data.count or 0
    end
    return 0
end

local canCarry = function(src, item, count)
    local inv = inventory()
    if inv == 'ox' then
        return exports.ox_inventory:CanCarryItem(src, item, count) == true
    end
    if inv == 'qb' then
        local ok, res = pcall(function()
            return exports['qb-inventory']:CanAddItem(src, item, count)
        end)
        if ok and type(res) == 'boolean' then return res end
        return true
    end
    if inv == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        if xPlayer.canCarryItem then return xPlayer.canCarryItem(item, count) == true end
        return true
    end
    return false
end

local giveItem = function(src, item, count)
    local inv = inventory()
    if inv == 'ox' then
        return exports.ox_inventory:AddItem(src, item, count) == true
    end
    if inv == 'qb' then
        if GetResourceState('qb-inventory') == 'started' then
            local ok, res = pcall(function()
                return exports['qb-inventory']:AddItem(src, item, count, false, false, 'hasib_peddialog')
            end)
            return ok and res == true
        end
        local player = corePlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, count) == true
    end
    if inv == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(item, count)
        return true
    end
    return false
end

local takeItem = function(src, item, count)
    local inv = inventory()
    if itemCount(src, item) < count then return false end
    if inv == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, count) == true
    end
    if inv == 'qb' then
        if GetResourceState('qb-inventory') == 'started' then
            local ok, res = pcall(function()
                return exports['qb-inventory']:RemoveItem(src, item, count, false, 'hasib_peddialog')
            end)
            return ok and res == true
        end
        local player = corePlayer(src)
        if not player then return false end
        return player.Functions.RemoveItem(item, count) == true
    end
    if inv == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        xPlayer.removeInventoryItem(item, count)
        return true
    end
    return false
end

local findPed = function(id)
    local list = Config.Peds or {}
    for i = 1, #list do
        if list[i].id == id then return list[i] end
    end
end

local nearPed = function(src, entry)
    if not entry or not entry.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local coords = entry.coords
    return #(pos - vector3(coords.x, coords.y, coords.z)) <= 5.0
end

local findOption = function(entry, id)
    local dialog = entry.dialog
    local options = dialog and dialog.options
    if options then
        for i = 1, #options do
            if options[i].id == id then return options[i] end
        end
    end
    local nodes = entry.nodes
    if type(nodes) ~= 'table' then return end
    for _, node in pairs(nodes) do
        local nodeOptions = type(node) == 'table' and node.options
        if nodeOptions then
            for i = 1, #nodeOptions do
                if nodeOptions[i].id == id then return nodeOptions[i] end
            end
        end
    end
end

local runOption = function(src, pedId, optionId)
    if type(pedId) ~= 'string' or type(optionId) ~= 'string' then
        return { success = false, reason = 'bad' }
    end
    local entry = findPed(pedId)
    if not entry or not nearPed(src, entry) then
        return { success = false, reason = 'far' }
    end
    local opt = findOption(entry, optionId)
    if not opt then
        return { success = false, reason = 'bad' }
    end
    local result = { success = true }
    if type(opt.fn) == 'function' then
        local ok, reason = opt.fn(src, pedId, optionId, result)
        if ok == false then
            result.success = false
            result.reason = reason or result.reason or 'bad'
        end
    end
    if result.success and type(opt.server) == 'string' and opt.server ~= '' then
        TriggerEvent(opt.server, src, pedId, optionId, result)
    end
    if result.success == nil then result.success = true end
    return result
end

local buyShop = function(src, pedId, cart, payment)
    if type(pedId) ~= 'string' or type(cart) ~= 'table' or #cart == 0 or #cart > 100 then
        return { success = false, reason = 'bad_item' }
    end
    local entry = findPed(pedId)
    if not entry or not nearPed(src, entry) then
        return { success = false, reason = 'far' }
    end
    local shop = entry.shop
    local items = shop and shop.items
    if not items then
        return { success = false, reason = 'bad_item' }
    end
    local byName = {}
    for i = 1, #items do
        byName[items[i].item] = items[i]
    end
    local lines = {}
    local subtotal = 0
    for i = 1, #cart do
        local row = cart[i]
        local itemName = type(row) == 'table' and row.item or nil
        local count = math.floor(tonumber(type(row) == 'table' and row.count) or 0)
        if type(itemName) ~= 'string' or count < 1 or count > 100 then
            return { success = false, reason = 'bad_item' }
        end
        local listing = byName[itemName]
        if not listing then
            return { success = false, reason = 'bad_item' }
        end
        local unit = tonumber(listing.price) or 0
        subtotal = subtotal + (unit * count)
        lines[#lines + 1] = { item = listing.item, amount = count }
    end
    local taxPct = tonumber(shop.tax) or 0
    local total = subtotal + math.ceil(subtotal * (taxPct / 100))
    local moneyType = shop.moneyType or 'cash'
    if payment == 'card' then
        moneyType = 'bank'
    elseif payment == 'cash' then
        moneyType = 'cash'
    end
    if moneyType ~= 'cash' and moneyType ~= 'bank' then
        return { success = false, reason = 'money' }
    end
    if total > 0 and (moneyOf(src, moneyType) or 0) < total then
        return { success = false, reason = 'money' }
    end
    for i = 1, #lines do
        if not canCarry(src, lines[i].item, lines[i].amount) then
            return { success = false, reason = 'inventory' }
        end
    end
    if total > 0 and not takeMoney(src, moneyType, total) then
        return { success = false, reason = 'money' }
    end
    local given = {}
    for i = 1, #lines do
        local line = lines[i]
        if not giveItem(src, line.item, line.amount) then
            for j = 1, #given do
                takeItem(src, given[j].item, given[j].amount)
            end
            if total > 0 then giveMoney(src, moneyType, total) end
            return { success = false, reason = 'inventory' }
        end
        given[#given + 1] = line
    end
    return { success = true, moneyType = moneyType, total = total }
end

RegisterNetEvent('hasib_peddialog:rpc', function(id, name, payload)
    local src = source
    if type(id) ~= 'number' or type(name) ~= 'string' or type(payload) ~= 'table' then return end
    local result = { success = false, reason = 'bad' }
    if name == 'buyShop' then
        result = buyShop(src, payload.pedId, payload.items, payload.payment)
    elseif name == 'option' then
        result = runOption(src, payload.pedId, payload.optionId)
    end
    TriggerClientEvent('hasib_peddialog:rpc:res', src, id, result)
end)

AddEventHandler('hasib_peddialog:fleet:paper', function(src, pedId, optionId, result)
    if (moneyOf(src, 'cash') or 0) < 2 or not takeMoney(src, 'cash', 2) then
        result.success = false
        result.reason = 'money'
        return
    end
    if not canCarry(src, 'paper', 1) or not giveItem(src, 'paper', 1) then
        giveMoney(src, 'cash', 2)
        result.success = false
        result.reason = 'inventory'
    end
end)

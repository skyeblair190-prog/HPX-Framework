-- hpx_core server adapter for the ATM DUI system by OsmFX Mods (https://osmfxmods.com).
-- Used with the author's permission. Original license: LICENSE-osm-atmdui.txt

if Bridge.Framework ~= 'hpx' then return end

if GetResourceState('ox_inventory') == 'missing' then
    error('^1[atm-dui] hpx_core requires ox_inventory for bank cards and receipts!^0')
    return
end

local core = exports.hpx_core

function Bridge.GetPlayer(source)
    return core:GetPlayer(source)
end

---Returns the player's cash or bank balance.
function Bridge.GetPlayerMoney(source, account)
    return tonumber(core:GetMoney(source, account)) or 0
end

function Bridge.AddMoney(source, account, amount, reason)
    return core:AddMoney(source, account, amount, reason or 'atm-transaction') == true
end

function Bridge.RemoveMoney(source, account, amount, reason)
    return core:RemoveMoney(source, account, amount, reason or 'atm-transaction') == true
end

---Returns the player's citizen id.
function Bridge.GetPlayerIdentifier(source)
    local player = Bridge.GetPlayer(source)
    return player and player.citizenid or nil
end

---Returns a readable character name.
function Bridge.GetPlayerName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return 'Unknown' end

    local charinfo = player.charinfo or {}
    local fullName = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')

    return fullName ~= '' and fullName or 'Unknown'
end

function Bridge.Notify(source, message, type)
    TriggerClientEvent('codera-notify:notify', source, message, type or 'inform', 5000)
end

function Bridge.HasItem(source, itemName)
    local count = exports.ox_inventory:Search(source, 'count', itemName)
    return count and count > 0 or false
end

---Returns metadata from the first matching inventory slot.
function Bridge.GetItemData(source, itemName)
    local items = exports.ox_inventory:Search(source, 'slots', itemName)
    if items and #items > 0 then
        return items[1].metadata or items[1].info
    end

    return nil
end

---Looks up an online player by citizen id.
function Bridge.GetPlayerByIdentifier(identifier)
    local players = core:GetPlayersData()
    for i = 1, #players do
        if players[i].citizenid == identifier then
            return { source = players[i].source, citizenid = identifier }
        end
    end

    return nil
end

---Checks that a character with this citizen id exists.
function Bridge.AccountExists(identifier)
    return MySQL.scalar.await('SELECT 1 FROM hpx_characters WHERE citizenid = ? LIMIT 1', { identifier }) ~= nil
end

---Adds bank money to a character that is not online.
function Bridge.CreditOffline(identifier, amount)
    local changed = MySQL.update.await(
        "UPDATE hpx_characters SET money = JSON_SET(money, '$.bank', COALESCE(JSON_EXTRACT(money, '$.bank'), 0) + ?) WHERE citizenid = ?",
        { amount, identifier }
    )

    return (changed or 0) > 0
end

function Bridge.AddItem(source, item, amount, info)
    return exports.ox_inventory:AddItem(source, item, amount, info)
end

exports('use_atm_receipt', function(event, item, inventory)
    if event == 'usingItem' then
        TriggerClientEvent('atm-dui:client:viewReceipt', inventory.id, item.metadata or item.info)
        return false -- don't consume
    end
end)

function Bridge.CreateCallback(name, cb)
    lib.callback.register(name, cb)
end

Bridge.Ready = true

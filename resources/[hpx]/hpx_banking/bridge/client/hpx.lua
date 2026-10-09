-- hpx_core client adapter for the ATM DUI system by OsmFX Mods (https://osmfxmods.com).
-- Used with the author's permission. Original license: LICENSE-osm-atmdui.txt

if Bridge.Framework ~= 'hpx' then return end

if GetResourceState('ox_inventory') == 'missing' then
    print('^1[atm-dui] hpx_core requires ox_inventory for bank cards and receipts!^0')
    return
end

---Returns normalized player data for the ATM UI.
function Bridge.GetPlayerData()
    local data = exports.hpx_core:GetPlayerData()
    if type(data) ~= 'table' or not data.citizenid then return nil end

    local charinfo = data.charinfo or {}
    local money = data.money or {}
    local fullName = ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')

    return {
        identifier = data.citizenid,
        name = fullName ~= '' and fullName or 'Unknown',
        cash = money.cash or 0,
        bank = money.bank or 0,
        job = data.job,
        gang = data.gang,
    }
end

---Shows a notification.
function Bridge.Notify(message, type)
    if GetResourceState('hpx_notify') == 'started' then
        exports.hpx_notify:Notify(message, type or 'inform', 5000)
    else
        lib.notify({ description = message, type = type or 'inform' })
    end
end

---Checks the local player's inventory for an item.
function Bridge.HasItem(itemName)
    local count = exports.ox_inventory:Search('count', itemName)
    return count and count > 0 or false
end

---Returns metadata from the first matching inventory slot.
function Bridge.GetItemData(itemName)
    local items = exports.ox_inventory:Search('slots', itemName)
    if items and #items > 0 then
        return items[1].metadata or items[1].info
    end

    return nil
end

---Triggers an ox_lib server callback.
function Bridge.TriggerCallback(name, cb, ...)
    local result = lib.callback.await(name, false, ...)
    if cb then cb(result) end

    return result
end

Bridge.Ready = true

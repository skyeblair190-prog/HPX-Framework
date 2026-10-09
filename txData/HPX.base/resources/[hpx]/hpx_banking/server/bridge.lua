-- ATM DUI system by OsmFX Mods (https://osmfxmods.com) - https://github.com/OsmFX-Mods/osm-atmdui
-- Used with the author's permission and adapted for hpx_core. Original license: LICENSE-osm-atmdui.txt

-- Server-side Bridge System
-- Auto-detects framework and loads appropriate adapter

Bridge = {}
Bridge.Framework = nil
Bridge.Ready = false

local function DetectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('hpx_core') == 'started' then
        return 'hpx'
    end

    return nil
end

-- Detect framework IMMEDIATELY (not in thread) so adapters can check it
Bridge.Framework = DetectFramework()

if not Bridge.Framework then
    print('^1[atm-dui] No supported framework detected!^0')
else
    print('^2[atm-dui] Server Bridge - Framework detected: ' .. Bridge.Framework .. '^0')
end

-- Wait for adapter to set Bridge.Ready
CreateThread(function()
    if not Bridge.Framework then return end
    
    local timeout = 0
    while not Bridge.Ready and timeout < 50 do -- 5 second timeout
        Wait(100)
        timeout = timeout + 1
    end
    
    if Bridge.Ready then
        print('^2[atm-dui] Server Bridge ready!^0')
    else
        print('^1[atm-dui] Server Bridge adapter failed to load!^0')
    end
end)

-- Server-side functions that adapters must implement:
-- Bridge.GetPlayer(source) - Returns player object
-- Bridge.GetPlayerMoney(source, account) - Get money ('cash' or 'bank')
-- Bridge.AddMoney(source, account, amount, reason) - Add money
-- Bridge.RemoveMoney(source, account, amount, reason) - Remove money
-- Bridge.GetPlayerIdentifier(source) - Get unique identifier
-- Bridge.GetPlayerName(source) - Get player name
-- Bridge.Notify(source, message, type) - Send notification
-- Bridge.HasItem(source, itemName) - Check if player has item
-- Bridge.GetItemData(source, itemName) - Get item metadata (for PIN)
-- Optional: Bridge.GetPlayerByIdentifier, Bridge.AccountExists, Bridge.CreditOffline, Bridge.AddItem

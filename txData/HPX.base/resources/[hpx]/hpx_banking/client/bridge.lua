-- ATM DUI system by OsmFX Mods (https://osmfxmods.com) - https://github.com/OsmFX-Mods/osm-atmdui
-- Used with the author's permission and adapted for hpx_core. Original license: LICENSE-osm-atmdui.txt

-- Client-side Bridge System
-- Auto-detects framework and loads appropriate adapter

local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

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

-- Detect framework IMMEDIATELY so adapters can check it at load time
Bridge.Framework = DetectFramework()

if not Bridge.Framework then
    print('^1[atm-dui] No supported framework detected!^0')
else
    print('^2[atm-dui] Framework detected: ' .. Bridge.Framework .. '^0')
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
        print('^2[atm-dui] Client Bridge ready!^0')
    else
        print('^1[atm-dui] Client Bridge adapter failed to load!^0')
    end
end)

-- Utility function to get locale text
function Bridge.GetLocale(key)
    local lang = Config.UI.language or 'en'
    local locales = Config.Locales[lang] or Config.Locales['en']
    return locales[key] or key
end

-- Client-side functions that adapters must implement:
-- Bridge.GetPlayerData() - Returns player data table
-- Bridge.Notify(message, type) - Show notification
-- Bridge.HasItem(itemName) - Check if player has item
-- Bridge.GetItemData(itemName) - Get item metadata

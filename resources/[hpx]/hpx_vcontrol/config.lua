Config = {}
Config.Command = 'vehcontrol'
Config.RequireVehicle = true
Config.UpdateInterval = 250
Config.AutoCloseDistance = 15.0
Config.DoorBones = {
    frontLeft  = 'door_dside_f',
    frontRight = 'door_pside_f',
    rearLeft   = 'door_dside_r',
    rearRight  = 'door_pside_r',
}

Config.DoorIndex = {
    frontLeft  = 0,
    frontRight = 1,
    rearLeft   = 2,
    rearRight  = 3,
    hood       = 4,
    trunk      = 5,
}

Config.WindowIndex = {
    frontLeft  = 0,
    frontRight = 1,
    rearLeft   = 2,
    rearRight  = 3,
}


Config.NotifyFramework = 'auto'

local function DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    elseif GetResourceState('ox_lib') == 'started' then
        return 'ox'
    end
    return 'standalone'
end

---@param msg string
---@param msgType string  -- 'success' | 'error' | 'info'
function Config.Notify(msg, msgType)
    msgType = msgType or 'info'

    local framework = Config.NotifyFramework
    if framework == 'auto' then
        framework = DetectFramework()
    end

    if framework == 'qbx' and GetResourceState('qbx_core') == 'started' then
        local ok = pcall(function()
            exports.qbx_core:Notify(msg, msgType)
        end)
        if ok then return end
    end

    if framework == 'qb' and GetResourceState('qb-core') == 'started' then
        local ok = pcall(function()
            local QBCore = exports['qb-core']:GetCoreObject()
            QBCore.Functions.Notify(msg, msgType)
        end)
        if ok then return end
    end

    if framework == 'esx' and GetResourceState('es_extended') == 'started' then
        local ok = pcall(function()
            local ESX = exports['es_extended']:getSharedObject()
            ESX.ShowNotification(msg)
        end)
        if ok then return end
    end

    if framework == 'ox' and GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({ description = msg, type = msgType })
        end)
        if ok then return end
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

Config.Locale = {
    notInVehicle   = 'You must be in a vehicle to use this.',
    seatOccupied   = 'That seat is already occupied.',
    seatTaken      = 'You cannot switch seats right now.',
}

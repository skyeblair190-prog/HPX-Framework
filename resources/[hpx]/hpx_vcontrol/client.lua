
local isMenuOpen   = false
local currentVeh   = nil


local windowState  = {} 
local lightState   = {} 
local hazardState  = {} 



local function GetVehNetId(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function VehicleHasBone(vehicle, boneName)
    return GetEntityBoneIndexByName(vehicle, boneName) ~= -1
end

local function GetVehicleDisplayName(vehicle)
    local model = GetEntityModel(vehicle)
    local rawName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(rawName)
    if not label or label == 'NULL' or label == '' then
        label = rawName
    end
    return label
end

local function IsDoorOpen(vehicle, doorIndex)
    return GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.10
end

local function GetPlayerVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        return veh
    end
    return nil
end



local function BuildVehicleStatus(vehicle)
    local netId = GetVehNetId(vehicle)
    windowState[netId] = windowState[netId] or {}

    local hasDoors = {
        frontLeft  = VehicleHasBone(vehicle, Config.DoorBones.frontLeft),
        frontRight = VehicleHasBone(vehicle, Config.DoorBones.frontRight),
        rearLeft   = VehicleHasBone(vehicle, Config.DoorBones.rearLeft),
        rearRight  = VehicleHasBone(vehicle, Config.DoorBones.rearRight),
    }

    local doors = {
        frontHood  = IsDoorOpen(vehicle, Config.DoorIndex.hood),
        rearHood   = IsDoorOpen(vehicle, Config.DoorIndex.trunk),
        frontLeft  = hasDoors.frontLeft  and IsDoorOpen(vehicle, Config.DoorIndex.frontLeft)  or false,
        frontRight = hasDoors.frontRight and IsDoorOpen(vehicle, Config.DoorIndex.frontRight) or false,
        rearLeft   = hasDoors.rearLeft   and IsDoorOpen(vehicle, Config.DoorIndex.rearLeft)   or false,
        rearRight  = hasDoors.rearRight  and IsDoorOpen(vehicle, Config.DoorIndex.rearRight)  or false,
    }

    local windows = {
        frontLeft  = windowState[netId][Config.WindowIndex.frontLeft]  or false,
        frontRight = windowState[netId][Config.WindowIndex.frontRight] or false,
        rearLeft   = windowState[netId][Config.WindowIndex.rearLeft]   or false,
        rearRight  = windowState[netId][Config.WindowIndex.rearRight]  or false,
    }

    local ped = PlayerPedId()
    local mySeat = -2 -- not in vehicle
    if GetVehiclePedIsIn(ped, false) == vehicle then
        for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
            if GetPedInVehicleSeat(vehicle, seat) == ped then
                mySeat = seat
                break
            end
        end
    end

    local occupied = {}
    for seat = -1, 2 do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        occupied[tostring(seat)] = occupant ~= 0
    end

    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    if not maxSeats or maxSeats <= 0 then
        maxSeats = GetVehicleMaxNumberOfPassengers(vehicle) + 1
    end

    return {
        vehicleName    = GetVehicleDisplayName(vehicle),
        doors          = doors,
        hasDoors       = hasDoors,
        windows        = windows,
        seats = {
            mySeat   = mySeat,
            occupied = occupied,
            maxSeats = maxSeats,
        },
        engine         = GetIsVehicleEngineRunning(vehicle),
        interiorLight  = lightState[netId] or false,
        hazard         = hazardState[netId] or false,
    }
end

local function PushStatus(msgType)
    if not currentVeh or not DoesEntityExist(currentVeh) then return end
    SendNUIMessage({
        type = msgType or 'updateStatus',
        status = BuildVehicleStatus(currentVeh),
    })
end



local function OpenMenu()
    if isMenuOpen then return end

    if Config.RequireVehicle then
        local veh = GetPlayerVehicle()
        if not veh then
            Config.Notify(Config.Locale.notInVehicle, 'error')
            return
        end
        currentVeh = veh
    else
        currentVeh = GetPlayerVehicle()
    end

    isMenuOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        type = 'openGeneral',
        status = currentVeh and BuildVehicleStatus(currentVeh) or nil,
    })

    CreateThread(function()
        while isMenuOpen do
            Wait(Config.UpdateInterval)

            if not currentVeh or not DoesEntityExist(currentVeh) then
             
                currentVeh = GetPlayerVehicle()
            end

            if currentVeh and DoesEntityExist(currentVeh) then
                PushStatus('updateStatus')
            end
        end
    end)
end

local function CloseMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    currentVeh = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'closeAll' })
end

local function ToggleMenu()
    if isMenuOpen then
        CloseMenu()
    else
        OpenMenu()
    end
end


RegisterCommand(Config.Command, function()
    ToggleMenu()
end, false)


RegisterNetEvent('codera-vcontrol:client:openMenu', OpenMenu)
RegisterNetEvent('codera-vcontrol:openMenu', OpenMenu)
RegisterNetEvent('codera-vcontrol:client:openVehControl', OpenMenu)
RegisterNetEvent('codera-vcontrol:openExternal', OpenMenu)

RegisterNetEvent('codera-vcontrol:client:closeMenu', CloseMenu)
RegisterNetEvent('codera-vcontrol:closeMenu', CloseMenu)

RegisterNetEvent('codera-vcontrol:client:toggleMenu', ToggleMenu)
RegisterNetEvent('codera-vcontrol:toggleMenu', ToggleMenu)


RegisterNetEvent('lorz-vcontrol:client:openMenu', OpenMenu)
RegisterNetEvent('lorz-vcontrol:openMenu', OpenMenu)
RegisterNetEvent('lorz-vcontrol:client:openVehControl', OpenMenu)
RegisterNetEvent('lorz-vcontrol:openExternal', OpenMenu)

RegisterNetEvent('lorz-vcontrol:client:closeMenu', CloseMenu)
RegisterNetEvent('lorz-vcontrol:closeMenu', CloseMenu)

RegisterNetEvent('lorz-vcontrol:client:toggleMenu', ToggleMenu)
RegisterNetEvent('lorz-vcontrol:toggleMenu', ToggleMenu)



exports('openVehControl', OpenMenu)
exports('openExternal', OpenMenu)
exports('openMenu', OpenMenu)
exports('closeVehControl', CloseMenu)
exports('closeMenu', CloseMenu)
exports('toggleMenu', ToggleMenu)



RegisterNUICallback('NUIFocusOff', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('doors', function(data, cb)
    if currentVeh and DoesEntityExist(currentVeh) and data and data.door ~= nil then
        local doorIndex = tonumber(data.door)
        if doorIndex then
            if IsDoorOpen(currentVeh, doorIndex) then
                SetVehicleDoorShut(currentVeh, doorIndex, false)
            else
                SetVehicleDoorOpen(currentVeh, doorIndex, false, false)
            end
            PushStatus('updateStatus')
        end
    end
    cb('ok')
end)

RegisterNUICallback('windows', function(data, cb)
    if currentVeh and DoesEntityExist(currentVeh) and data and data.window ~= nil then
        local windowIndex = tonumber(data.window)
        if windowIndex then
            local netId = GetVehNetId(currentVeh)
            windowState[netId] = windowState[netId] or {}
            local isOpen = windowState[netId][windowIndex] or false

            if isOpen then
                RollUpWindow(currentVeh, windowIndex)
            else
                RollDownWindow(currentVeh, windowIndex)
            end
            windowState[netId][windowIndex] = not isOpen
            PushStatus('updateStatus')
        end
    end
    cb('ok')
end)

RegisterNUICallback('seatchange', function(data, cb)
    if currentVeh and DoesEntityExist(currentVeh) and data and data.seat ~= nil then
        local seatIndex = tonumber(data.seat)
        local ped = PlayerPedId()
        if seatIndex then
            local occupant = GetPedInVehicleSeat(currentVeh, seatIndex)
            if occupant ~= 0 and occupant ~= ped then
                Config.Notify(Config.Locale.seatOccupied, 'error')
            else
                TaskWarpPedIntoVehicle(ped, currentVeh, seatIndex)
            end
            PushStatus('updateStatus')
        end
    end
    cb('ok')
end)

RegisterNUICallback('ignition', function(_, cb)
    if currentVeh and DoesEntityExist(currentVeh) then
        local running = GetIsVehicleEngineRunning(currentVeh)
        SetVehicleEngineOn(currentVeh, not running, false, true)
        PushStatus('updateStatus')
    end
    cb('ok')
end)

RegisterNUICallback('interiorLight', function(_, cb)
    if currentVeh and DoesEntityExist(currentVeh) then
        local netId = GetVehNetId(currentVeh)
        local newState = not (lightState[netId] or false)
        lightState[netId] = newState
        SetVehicleInteriorlight(currentVeh, newState)
        PushStatus('updateStatus')
    end
    cb('ok')
end)

RegisterNUICallback('hazard', function(_, cb)
    if currentVeh and DoesEntityExist(currentVeh) then
        local netId = GetVehNetId(currentVeh)
        hazardState[netId] = not (hazardState[netId] or false)
        PushStatus('updateStatus')
    end
    cb('ok')
end)


CreateThread(function()
    while true do
        local sleep = 500

        if currentVeh and DoesEntityExist(currentVeh) then
            local netId = GetVehNetId(currentVeh)
            if hazardState[netId] then
                SetVehicleIndicatorLights(currentVeh, 0, true) -- left
                SetVehicleIndicatorLights(currentVeh, 1, true) -- right
                sleep = 0 -- needs to run every frame to override natural indicator decay
            end
        end

        Wait(sleep)
    end
end)


CreateThread(function()
    while true do
        Wait(500)
        if isMenuOpen and Config.RequireVehicle then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                CloseMenu()
            elseif GetVehiclePedIsIn(ped, false) == 0 and (not currentVeh or GetVehiclePedIsIn(ped, true) ~= currentVeh) then
                CloseMenu()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isMenuOpen then
        SetNuiFocus(false, false)
    end
end)

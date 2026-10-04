local config = require 'config.client'
if not config.enableClient then return end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param category VehicleType
---@param model number
---@return boolean
local function isModelOfType(category, model)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClassFromName(model)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.hpx_notify:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.hpx_notify:Notify(locale('error.in_vehicle'), 'error')
            return
        end

        local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then return end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.hpx_notify:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
end

local uiOpen = false
---@type { garageName: string, accessPoint: integer, zoneId: string }?
local uiCtx

local function closeGarageUi()
    if not uiOpen then return end
    uiOpen = false
    uiCtx = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
---@param zoneId string
local function openGarageMenu(garageName, garageInfo, accessPoint, zoneId)
    if uiOpen then return end

    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.hpx_notify:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    for i = #vehicleEntities, 1, -1 do
        if not isModelOfType(garageInfo.vehicleType, joaat(vehicleEntities[i].modelName)) then
            table.remove(vehicleEntities, i)
        end
    end

    table.sort(vehicleEntities, function(a, b)
        return a.modelName < b.modelName
    end)

    local citizenid = lib.callback.await('qbx_garages:server:getCitizenId', false)
    local isDepot = garageInfo.type == GarageType.DEPOT
    local list = {}
    for i = 1, #vehicleEntities do
        local v = vehicleEntities[i]
        local label = GetLabelText(GetDisplayNameFromVehicleModel(joaat(v.modelName)))
        local props = v.props or {}
        list[#list + 1] = {
            id = v.id,
            model = v.modelName,
            label = label ~= 'NULL' and label or v.modelName,
            plate = props.plate or '',
            state = v.state,
            seats = GetVehicleModelNumberOfSeats(joaat(v.modelName)),
            fuel = math.floor((props.fuelLevel or 100) + 0.5),
            engine = math.floor((props.engineHealth or 1000) / 10 + 0.5),
            body = math.floor((props.bodyHealth or 1000) / 10 + 0.5),
            depotPrice = v.depotPrice or 0,
            depot = isDepot,
            owned = v.citizenid == nil or v.citizenid == citizenid,
        }
    end

    uiOpen = true
    uiCtx = { garageName = garageName, accessPoint = accessPoint, zoneId = zoneId }
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        vehicles = list,
        imageUrl = config.ui.vehicleImageUrl,
        currency = config.ui.currency,
    })
end

RegisterNUICallback('close', function(_, cb)
    if uiOpen then
        uiOpen = false
        uiCtx = nil
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

RegisterNUICallback('retrieve', function(data, cb)
    cb('ok')
    local ctx = uiCtx
    uiOpen = false
    uiCtx = nil
    SetNuiFocus(false, false)
    if not ctx or not data or not data.id then return end
    takeOutOfGarage(data.id, ctx.garageName, ctx.accessPoint)
end)

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.hpx_notify:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        exports.hpx_notify:Notify(locale('success.vehicle_parked'), 'primary', 4500)
    else
        exports.hpx_notify:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not lib.callback.await('qbx_garages:server:hasGroupAccess', false, garage.groups) then
        exports.hpx_notify:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.hpx_notify:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

local radialIds = {}

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
---@param hasExplicitDrop boolean whether the config explicitly set a separate dropPoint
local function createZones(garageName, garage, accessPoint, accessPointIndex, hasExplicitDrop)
    CreateThread(function()
        local useRadius = accessPoint.useRadius or config.radial.useRadius
        local dropUseRadius = accessPoint.dropUseRadius or config.radial.dropUseRadius
        local openId = ('qbx_garage_open_%s_%s'):format(garageName, accessPointIndex)
        local parkId = ('qbx_garage_park_%s_%s'):format(garageName, accessPointIndex)
        radialIds[#radialIds + 1] = openId
        radialIds[#radialIds + 1] = parkId

        local inMainZone = false

        -- Main access point: on foot it opens the garage menu, while driving a compatible
        -- vehicle it swaps to a "Store Vehicle" option instead. Re-evaluated live via
        -- lib.onCache so getting in/out of a car while standing in the zone updates instantly.
        local function updateMainRadial()
            if not inMainZone then return end
            lib.removeRadialItem(openId)
            if cache.vehicle and garage.type ~= GarageType.DEPOT then
                lib.addRadialItem({
                    id = openId,
                    icon = config.radial.parkIcon,
                    label = config.radial.parkLabel,
                    onSelect = function()
                        if not checkCanAccess(garage) then return end
                        parkVehicle(cache.vehicle, garageName)
                    end,
                })
            elseif not cache.vehicle then
                lib.addRadialItem({
                    id = openId,
                    icon = config.radial.icon,
                    label = garage.label or config.radial.label,
                    onSelect = function()
                        if not checkCanAccess(garage) then return end
                        openGarageMenu(garageName, garage, accessPointIndex, openId)
                    end,
                })
            end
        end

        lib.zones.sphere({
            coords = accessPoint.coords,
            radius = useRadius,
            onEnter = function()
                inMainZone = true
                updateMainRadial()
            end,
            onExit = function()
                inMainZone = false
                lib.removeRadialItem(openId)
                if uiCtx and uiCtx.zoneId == openId then closeGarageUi() end
            end,
            debug = config.debugPoly,
        })

        lib.onCache('vehicle', updateMainRadial)

        -- Optional separate drop-off point, only created when the config explicitly sets one
        -- (e.g. a distant hangar/dock spawn). Always available for storing a vehicle.
        if hasExplicitDrop and garage.type ~= GarageType.DEPOT then
            local inDropZone = false

            local function updateDropRadial()
                if not inDropZone then return end
                lib.removeRadialItem(parkId)
                if cache.vehicle then
                    lib.addRadialItem({
                        id = parkId,
                        icon = config.radial.parkIcon,
                        label = config.radial.parkLabel,
                        onSelect = function()
                            if not checkCanAccess(garage) then return end
                            parkVehicle(cache.vehicle, garageName)
                        end,
                    })
                end
            end

            lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropUseRadius,
                onEnter = function()
                    inDropZone = true
                    updateDropRadial()
                end,
                onExit = function()
                    inDropZone = false
                    lib.removeRadialItem(parkId)
                end,
                debug = config.debugPoly,
            })

            lib.onCache('vehicle', updateDropRadial)
        end
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
local function createBlips(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarage(name, garage)
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]
        local hasExplicitDrop = accessPoint.dropPoint ~= nil
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn or accessPoint.coords

        if accessPoint.blip then
            createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i, hasExplicitDrop)
    end
end

local function createGarages()
    local garages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

CreateThread(function()
    createGarages()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if uiOpen then SetNuiFocus(false, false) end
    for i = 1, #radialIds do
        lib.removeRadialItem(radialIds[i])
    end
end)

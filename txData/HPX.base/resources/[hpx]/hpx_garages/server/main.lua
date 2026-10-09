local logger = require 'server.logger'

---@class ErrorResult
---@field code string
---@field message string

---@class PlayerVehicle
---@field id number
---@field citizenid? string
---@field modelName string
---@field garage string
---@field state VehicleState
---@field depotPrice integer
---@field props table ox_lib properties table

Config = require 'config.server'
Storage = require 'server.storage'
---@type table<string, GarageConfig>
Garages = Config.garages

---@param source number
---@return table?
function GetHPXPlayer(source)
    local player = exports.hpx_core:GetPlayer(source)
    if player then player.source = source end
    return player
end

---@param source number
---@param message string
---@param kind string
function Notify(source, message, kind)
    TriggerClientEvent('codera-notify:notify', source, message, kind, 5000)
end

---@param groups string | string[] | table<string, number>
---@param job? { name: string, grade: number }
---@param gang? { name: string, grade: number }
---@return boolean
function HasPrimaryGroup(groups, job, gang)
    if type(groups) == 'string' then
        groups = { [groups] = 0 }
    elseif type(groups) ~= 'table' then
        return false
    end

    for name, minGrade in pairs(groups) do
        if type(name) == 'number' then
            name, minGrade = minGrade, 0
        end
        minGrade = tonumber(minGrade) or 0
        if job and job.name == name and (tonumber(job.grade) or 0) >= minGrade then return true end
        if gang and gang.name == name and (tonumber(gang.grade) or 0) >= minGrade then return true end
    end

    return false
end

lib.callback.register('qbx_garages:server:getCitizenId', function(source)
    local player = GetHPXPlayer(source)
    return player and player.citizenid
end)

lib.callback.register('qbx_garages:server:hasGroupAccess', function(source, groups)
    local player = GetHPXPlayer(source)
    return player ~= nil and HasPrimaryGroup(groups, player.job, player.gang)
end)

lib.callback.register('qbx_garages:server:getGarages', function()
    return Garages
end)

---Returns garages for use server side.
local function getGarages()
    return Garages
end
exports('GetGarages', getGarages)

---@param name string
---@param config GarageConfig
local function registerGarage(name, config)
    Garages[name] = config
    TriggerClientEvent('qbx_garages:client:garageRegistered', -1, name, config)
    TriggerEvent('qbx_garages:server:garageRegistered', name, config)
end

exports('RegisterGarage', registerGarage)

---Sets the vehicle's garage. It is the caller's responsibility to make sure the vehicle is not currently spawned in the world, or else this may have no effect.
---@param vehicleId integer
---@param garageName string
---@return boolean success, ErrorResult?
local function setVehicleGarage(vehicleId, garageName)
    local garage = Garages[garageName]
    if not garage then
        return false, {
            code = 'not_found',
            message = string.format('garage name %s not found. Did you forget to register it?', garageName)
        }
    end

    local state = garage.type == GarageType.DEPOT and VehicleState.IMPOUNDED or VehicleState.GARAGED
    local numRowsAffected = Storage.setVehicleGarage(vehicleId, garageName, state)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleGarage', setVehicleGarage)

---Sets the vehicle's price for retrieval at a depot. Only affects vehicles that are OUT or IMPOUNDED.
---@param vehicleId integer
---@param depotPrice integer
---@return boolean success, ErrorResult?
local function setVehicleDepotPrice(vehicleId, depotPrice)
    local numRowsAffected = Storage.setVehicleDepotPrice(vehicleId, depotPrice)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleDepotPrice', setVehicleDepotPrice)

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@param garage string
---@return GarageType?
function GetGarageType(garage)
    return Garages[garage]?.type
end

---@class PlayerVehiclesFilters
---@field citizenid? string
---@field states? VehicleState|VehicleState[]
---@field garage? string

---@param source number
---@param garageName string
---@return PlayerVehiclesFilters
function GetPlayerVehicleFilter(source, garageName)
    local player = GetHPXPlayer(source)
    local garage = Garages[garageName]
    local filter = {}
    filter.citizenid = not garage.shared and player.citizenid or nil
    filter.states = garage.states or VehicleState.GARAGED
    filter.garage = not garage.skipGarageCheck and garageName or nil
    return filter
end

---@param source number
---@param garageName string
---@return GarageConfig?
function TryGetGarage(source, garageName)
    local garage = Garages[garageName]
    if garage then return garage end

    logger.log({
        source = source,
        event = 'error',
        message = string.format(
            'Attempted to spawn a vehicle from a non-existent garage: %s',
            garageName
        ),
        webhook = Config.logging.webhook.error,
        color = 'red'
    })
end

local function getCanAccessGarage(player, garage)
    if not player or not garage then return false end
    if garage.groups and not HasPrimaryGroup(garage.groups, player.job, player.gang) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.source) then
        return false
    end
    return true
end

---@param vehicle number vehicle entity
---@return VehicleType
local function getVehicleType(vehicle)
    local entityType = GetVehicleType(vehicle)
    if entityType == 'heli' or entityType == 'plane' then
        return VehicleType.AIR
    elseif entityType == 'boat' or entityType == 'submarine' then
        return VehicleType.SEA
    else
        return VehicleType.CAR
    end
end

---@param source number
---@param garageName string
---@return PlayerVehicle[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garageName)
    local player = GetHPXPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end
    if not getCanAccessGarage(player, garage) then return end
    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicles = exports.hpx_core:GetPlayerVehicles(filter)
    local toSend = {}
    if not playerVehicles[1] then return end

    for _, vehicle in pairs(playerVehicles) do
        if not FindPlateOnServer(vehicle.props.plate) then
            OverrideFreeDepotPriceForOutVehicle(vehicle)
            toSend[#toSend + 1] = vehicle
        end
    end
    return toSend
end)

---@param source number
---@param vehicleId string
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName, vehicle)
    local garageType = GetGarageType(garageName)
    --- DEPOTS are only for retrieving, not storing
    if garageType == GarageType.DEPOT then return false end
    if not vehicleId then return false end
    local player = GetHPXPlayer(source)
    local garage = Garages[garageName]
    if not getCanAccessGarage(player, garage) then
        return false
    end
    ---@type PlayerVehicle
    local playerVehicle = exports.hpx_core:GetPlayerVehicle(vehicleId)
    if not playerVehicle or getVehicleType(vehicle) ~= garage.vehicleType then
        return false
    end
    if not garage.shared then
        if playerVehicle.citizenid ~= player.citizenid then
            return false
        end
    end
    return true
end

lib.callback.register('qbx_garages:server:isParkable', function(source, garage, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.hpx_core:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    return isParkable(source, vehicleId, garage, vehicle)
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/communityox/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage)
    assert(Garages[garage] ~= nil, string.format('Garage %s not found. Did you register this garage?', garage))
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid or exports.hpx_core:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    local owned = isParkable(source, vehicleId, garage, vehicle) --Check ownership
    if not owned then
        Notify(source, locale('error.not_owned'), 'error')
        return
    end

    exports.hpx_core:SaveVehicle(vehicle, {
        garage = garage,
        state = VehicleState.GARAGED,
        props = props
    })

    DeleteEntity(vehicle)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)
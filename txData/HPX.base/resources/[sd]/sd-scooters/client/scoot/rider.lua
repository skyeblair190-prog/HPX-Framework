---Keep the standing grip on the rotating bars; let the authored entry/exit
---animations control the arms while the rider reaches for or releases them.
---
---GTA's seated bike arm IK overrides the authored wrist pose, so each seated driver gets position-only
---hand targets on the handlebars bone. IK targets only last one frame, so those two calls are the
---whole per-frame cost; everything else (finding riders, reading seat/exit state, visibility) runs on
---a frame counter a few times a second, and no native is spent on bookkeeping in between.
local MODEL = joaat('sd_scoot')
local fleet = require 'client.scoot.fleet'
local HANDLEBARS = 49213 -- skeleton tag, not the bone array index
local GRIP_X, GRIP_Y, GRIP_Z = 0.238336, -0.0798, 1.0110
local LEFT_X = -GRIP_X
local EXIT_TASK = 2 -- CTaskExitVehicle; checked against the running b3258 client
local DRAW_DISTANCE = 60.0 -- remote riders further than this (or off screen) skip the IK; nobody can see their hands

---frame counts; at 60-144 fps these land around 0.1 s / 0.25 s / 1 s
local STATE_FRAMES = 6 -- re-read a known rider's seat/exit state
local DISCOVER_FRAMES = 15 -- look for drivers on nearby scooters and the local player climbing on
local PED_SCAN_FRAMES = 60 -- look for other peds climbing on (walks the ped pool); a multiple of DISCOVER_FRAMES

local SetIkTarget, SetPedCanArmIk = SetIkTarget, SetPedCanArmIk
local GetPedInVehicleSeat, GetIsTaskActive = GetPedInVehicleSeat, GetIsTaskActive

---@type table<integer, { vehicle: integer, seated: boolean, armIk: boolean|nil, draw: boolean }> ped -> rider state
local riders = {}
local running = true

---True for a real vehicle handle of the scooter model.
---@param vehicle integer
---@return boolean
local function scooter(vehicle)
    return vehicle ~= 0 and GetEntityModel(vehicle) == MODEL
end

---Work out which scooter a ped is riding, mounting or dismounting, and whether it is fully seated. Returns nothing when the ped is not on a scooter or cannot hold the bars.
---@param ped integer
---@param previousVehicle integer|nil the scooter it was on last check, to follow an exit in progress
---@return integer|nil vehicle
---@return boolean|nil seated
local function stateFor(ped, previousVehicle)
    if not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedRagdoll(ped)
        or IsPedDoingDriveby(ped) then return end
    local entering = GetVehiclePedIsEntering(ped)
    if scooter(entering) and IsPedGettingIntoAVehicle(ped)
        and GetSeatPedIsTryingToEnter(ped) == -1 then
        return entering, false
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if scooter(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
        return vehicle, IsPedSittingInVehicle(ped, vehicle) and not GetIsTaskActive(ped, EXIT_TASK)
    end
    if previousVehicle and scooter(previousVehicle) and GetIsTaskActive(ped, EXIT_TASK) then
        return previousVehicle, false
    end
end

---Stop the grip loop and give every tracked rider its normal arm IK back.
local function stop()
    running = false
    for ped in pairs(riders) do
        if DoesEntityExist(ped) then SetPedCanArmIk(ped, true) end
    end
    riders = {}
end

---@type boolean a rider was just found; read its state this frame rather than on the next STATE_FRAMES tick
local fresh = false

---Start tracking a ped as a rider; its state is read on this frame.
---@param ped integer
local function track(ped)
    if not riders[ped] then
        riders[ped] = { vehicle = 0, seated = false, armIk = nil, draw = true }
        fresh = true
    end
end

---Refresh one rider's state; a ped that is no longer riding is released.
local function refresh(ped, r, me, camera)
    if not (r.seated and GetPedInVehicleSeat(r.vehicle, -1) == ped and not GetIsTaskActive(ped, EXIT_TASK)) then
        local vehicle, seated = stateFor(ped, r.vehicle ~= 0 and r.vehicle or nil)
        if not vehicle then
            if DoesEntityExist(ped) then SetPedCanArmIk(ped, true) end
            riders[ped] = nil
            return
        end
        r.vehicle, r.seated = vehicle, seated
    end
    r.draw = ped == me or (IsEntityOnScreen(ped) and #(GetEntityCoords(ped) - camera) < DRAW_DISTANCE)
end

---Handlebar grip: finds drivers and mounting peds on nearby scooters and sets both hand IK targets every frame for seated riders. Discovery and state reads run on frame counters; with no riders it sleeps 250 ms near a scooter, 1 s otherwise.
CreateThread(function()
    local frame = 0
    while running do
        frame = frame + 1

        if frame % DISCOVER_FRAMES == 0 then
            local near = fleet.list()
            if near[1] then
                for i = 1, #near do
                    local driver = GetPedInVehicleSeat(near[i], -1)
                    if driver ~= 0 then track(driver) end
                end
                local me = PlayerPedId()
                if not riders[me] and scooter(GetVehiclePedIsEntering(me)) then track(me) end
                if frame % PED_SCAN_FRAMES == 0 then
                    local set = {}
                    for i = 1, #near do set[near[i]] = true end
                    local peds = GetGamePool('CPed')
                    for i = 1, #peds do
                        local ped = peds[i]
                        if not riders[ped] and set[GetVehiclePedIsEntering(ped)] then track(ped) end
                    end
                end
            end
        end

        if next(riders) then
            if fresh or frame % STATE_FRAMES == 0 then
                fresh = false
                local me, camera = PlayerPedId(), GetFinalRenderedCamCoord()
                for ped, r in pairs(riders) do refresh(ped, r, me, camera) end
            end
            for ped, r in pairs(riders) do
                if r.seated then
                    if r.armIk ~= true then SetPedCanArmIk(ped, true); r.armIk = true end
                    if r.draw then
                        SetIkTarget(ped, 3, r.vehicle, HANDLEBARS, LEFT_X, GRIP_Y, GRIP_Z, 1, -1, -1)
                        SetIkTarget(ped, 4, r.vehicle, HANDLEBARS, GRIP_X, GRIP_Y, GRIP_Z, 1, -1, -1)
                    end
                else
                    SetPedCanArmIk(ped, false)
                    r.armIk = false
                end
            end
            Wait(0)
        else
            frame = frame - (frame % DISCOVER_FRAMES) + DISCOVER_FRAMES - 1
            Wait(fleet.any() and 250 or 1000)
        end
    end
end)

---Electric: no petrol tank, so GTA never burns fuel and fuel scripts (ox_fuel) skip it; the battery lives
---in state.fuel. GTA still refuses to start an engine whose hidden petrol level is 0, and a tankless
---vehicle spawns at 0, so every scooter gets that level held at 100. The one the local player is
---mounting is checked every frame, because the seat's automatic ignition is tried the moment they sit
---down; once its engine runs, a check every half second is plenty.
local function topUp(v)
    local level = GetVehicleFuelLevel(v)
    if level >= 100.0 then return end
    SetVehicleFuelLevel(v, 100.0)
    if level <= 0.0 and GetPedInVehicleSeat(v, -1) == PlayerPedId() and not GetIsVehicleEngineRunning(v) then
        SetVehicleEngineOn(v, true, true, false)
    end
end

---@type table<integer, integer> vehicle -> game time its tank volume is next checked
local tankCheckAt = {}

---Drop a scooter's petrol tank volume to 0 (rechecked every 5 s) and keep its hidden fuel level topped up.
---@param v integer vehicle handle
---@param now integer game timer
local function energise(v, now)
    if now >= (tankCheckAt[v] or 0) then
        tankCheckAt[v] = now + 5000
        if GetVehicleHandlingFloat(v, 'CHandlingData', 'fPetrolTankVolume') > 0.0 then
            SetVehicleHandlingFloat(v, 'CHandlingData', 'fPetrolTankVolume', 0.0)
        end
    end
    topUp(v)
end

---Electric power: tops up the scooter the local player is on or mounting every tick, and sweeps nearby scooters to strip their tank and fuel them. Runs every frame while mounting or the engine is off, 500 ms while riding, 100 ms near a scooter, 500 ms otherwise.
CreateThread(function()
    local nextSweep = 0
    while running do
        local ped = PlayerPedId()
        local mine = GetVehiclePedIsIn(ped, false)
        local entering = mine == 0
        if entering then mine = GetVehiclePedIsEntering(ped) end
        local riding = scooter(mine)
        local urgent = false
        if riding then
            topUp(mine)
            urgent = entering or not GetIsVehicleEngineRunning(mine)
        end
        local now = GetGameTimer()
        if now >= nextSweep then
            local seen = {}
            for _, v in ipairs(fleet.list()) do
                if GetEntityModel(v) == MODEL then
                    energise(v, now)
                    seen[v] = true
                end
            end
            for v in pairs(tankCheckAt) do
                if not seen[v] then tankCheckAt[v] = nil end
            end
            nextSweep = now + (riding and 1000 or 250)
        end
        Wait(urgent and 0 or (riding and 500 or (fleet.any() and 100 or 500)))
    end
end)

---Restore arm IK on every rider when this resource stops.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stop() end
end)

---Module export: the stop function.
package.preload['client.scoot.rider'] = function() return stop end

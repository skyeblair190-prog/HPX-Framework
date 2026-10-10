---Live handling: every sd_scoot this client streams gets the values the server publishes (the active
---profile laid over data/handling.meta). The admin panel can preview an unsaved draft on the admin's own
---scooter and hand it over for a test ride with a speed readout.
---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
local fleet = require 'client.scoot.fleet'

---@type table Handling editor config (configs/shared/handling.lua).
local CFG = config.Handling
---@type integer
local MODEL = joaat(config.Scooters.Model)
---@type string GlobalState key the server publishes the resolved values under.
local STATE_KEY = 'sd_scoot:handling'
---@type boolean Speed unit the telemetry reports in (configs/shared/scooters.lua > SpeedUnit).
local MPH = config.Scooters.SpeedUnit == 'mph'
local SPEED_FACTOR = MPH and 2.236936 or 3.6
---@type number Launch timer target: 0-30 mph or 0-50 km/h.
local LAUNCH_TARGET = MPH and 30.0 or 50.0

---@type table[] Editable fields: { name, class, type, unit }.
local fields = {}
for _, group in ipairs(CFG.Groups) do
    for _, f in ipairs(group.fields) do
        fields[#fields + 1] = { name = f.name, class = f.class or 'CHandlingData', type = f.type or 'float', unit = f.unit }
    end
end

---@type table<string, integer|false> Horn id -> base-game horn hash, false for 'none' (horn switched off).
local HORNS = {}
for _, h in ipairs(CFG.Horns or {}) do HORNS[h.id] = h.hash or false end

local module = {}

---Give a scooter the chosen horn, or switch its horn off. Unknown ids fall back to Config.Handling.DefaultHorn.
---@param v integer
---@param id any
local function setHorn(v, id)
    local hash = HORNS[id]
    if hash == nil then hash = HORNS[CFG.DefaultHorn] end
    if hash then
        SetHornEnabled(v, true)
        OverrideVehHorn(v, true, hash)
    else
        SetHornEnabled(v, false)
    end
end

---@type table<integer, string> Vehicle handle -> the revision last applied to it.
local applied = {}
---@type table|nil { vehicle, values, seq } unsaved draft on the admin's own scooter
local preview
local previewSeq = 0
---@type integer|nil A scooter this module spawned for a test ride; deleted when the panel closes.
local testScooter
---@type boolean
local testing = false

---Read one handling field off a vehicle, converting degree fields from radians.
---@param v integer vehicle
---@param f table field entry { name, class, type, unit }
---@return number|vector3
local function read(v, f)
    if f.type == 'vector' then return GetVehicleHandlingVector(v, f.class, f.name) end
    if f.type == 'int' then return GetVehicleHandlingInt(v, f.class, f.name) end
    local n = GetVehicleHandlingFloat(v, f.class, f.name)
    return f.unit == 'deg' and math.deg(n) or n
end

---Write every field whose current value differs. Returns how many handling fields changed (the horn is
---always set and not counted). hornOnly skips the handling fields, for servers with the editor off.
---@param v integer
---@param values table<string, number|table|string>
---@param hornOnly boolean|nil
---@return integer
local function apply(v, values, hornOnly)
    local changed = 0
    for _, f in ipairs(fields) do
        local want = values[f.name]
        if f.type == 'horn' then
            setHorn(v, want)
        elseif want ~= nil and not hornOnly then
            local have = read(v, f)
            if f.type == 'vector' then
                if type(want) == 'table' and (math.abs(have.x - want.x) > 1e-4 or math.abs(have.y - want.y) > 1e-4 or math.abs(have.z - want.z) > 1e-4) then
                    SetVehicleHandlingVector(v, f.class, f.name, vector3(want.x + 0.0, want.y + 0.0, want.z + 0.0))
                    changed = changed + 1
                end
            elseif type(want) == 'number' and math.abs(have - want) > 1e-4 then
                if f.type == 'int' then
                    SetVehicleHandlingInt(v, f.class, f.name, math.floor(want + 0.5))
                else
                    SetVehicleHandlingFloat(v, f.class, f.name, (f.unit == 'deg' and math.rad(want) or want) + 0.0)
                end
                changed = changed + 1
            end
        end
    end
    if changed > 0 then ModifyVehicleTopSpeed(v, 1.0) end
    return changed
end

---Apply the published values (or the preview) to every scooter that has not had them yet.
local function sweep()
    local hornOnly = CFG.Enabled == false
    local state = GlobalState[STATE_KEY]
    if type(state) ~= 'table' or type(state.values) ~= 'table' then return end
    local seen = {}
    for _, v in ipairs(fleet.all()) do
        if DoesEntityExist(v) and GetEntityModel(v) == MODEL then
            seen[v] = true
            local tag, values
            if preview and preview.vehicle == v then
                tag, values = 'preview:' .. preview.seq, preview.values
            else
                tag, values = 'rev:' .. tostring(state.rev), state.values
            end
            if applied[v] ~= tag then
                apply(v, values, hornOnly)
                applied[v] = tag
            end
        end
    end
    for v in pairs(applied) do
        if not seen[v] then applied[v] = nil end
    end
end

---Applies the published handling (or a preview) to streamed scooters, every Config.Handling.ApplyEveryMs (1 s by default).
CreateThread(function()
    while true do
        local okay, err = pcall(sweep)
        if not okay then log.error('handling', 'sweep failed: %s', tostring(err)) end
        Wait(CFG.ApplyEveryMs or 1000)
    end
end)

---New published values: forget what was applied and sweep again on the next tick.
AddStateBagChangeHandler(STATE_KEY, 'global', function()
    applied = {}
    SetTimeout(0, function() pcall(sweep) end)
end)

---The scooter the local player drives, or 0.
---@return integer
local function drivenScooter()
    local ped = PlayerPedId()
    local v = GetVehiclePedIsIn(ped, false)
    if v ~= 0 and GetEntityModel(v) == MODEL and GetPedInVehicleSeat(v, -1) == ped then return v end
    return 0
end

---Show an unsaved draft on the admin's own scooter (nothing when they are not riding one).
---@param values table<string, number|table>|nil
---@return boolean appliedToScooter
function module.setPreview(values)
    local v = (preview and preview.vehicle and DoesEntityExist(preview.vehicle)) and preview.vehicle or drivenScooter()
    if v == 0 or type(values) ~= 'table' then return false end
    previewSeq = previewSeq + 1
    preview = { vehicle = v, values = values, seq = previewSeq }
    apply(v, values)
    applied[v] = 'preview:' .. previewSeq
    return true
end

---Drop the draft: the scooter goes back to the published values on the next sweep (run now).
function module.clearPreview()
    if not preview then return end
    applied[preview.vehicle] = nil
    preview = nil
    pcall(sweep)
end

---Sound a horn from the handling editor on the admin's scooter (or the nearest one within 15 m), then
---hand that scooter back to the horn it had. Returns false when no scooter is close.
---@param id string
---@return boolean
function module.previewHorn(id)
    local v = drivenScooter()
    if v == 0 then
        local here, best = GetEntityCoords(PlayerPedId()), 15.0
        for _, s in ipairs(fleet.list()) do
            if DoesEntityExist(s) and GetEntityModel(s) == MODEL then
                local d = #(GetEntityCoords(s) - here)
                if d < best then v, best = s, d end
            end
        end
    end
    if v == 0 or HORNS[id] == nil then return false end
    if HORNS[id] then
        setHorn(v, id)
        StartVehicleHorn(v, 900, joaat('HELDDOWN'), false)
    end
    SetTimeout(1100, function()
        if not DoesEntityExist(v) then return end
        applied[v] = nil
        pcall(sweep)
    end)
    return true
end

---Whether a handling test ride is running.
---@return boolean
function module.isTesting()
    return testing
end

---Put the admin on a scooter for a test ride: the one they ride, or a fresh one beside them.
---@return integer|nil vehicle, string|nil errKey
local function testVehicle()
    local v = drivenScooter()
    if v ~= 0 then return v end
    if testScooter and DoesEntityExist(testScooter) then
        TaskWarpPedIntoVehicle(PlayerPedId(), testScooter, -1)
        return testScooter
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return nil, 'err.handling_other_vehicle' end
    local hash = lib.requestModel(MODEL, 5000)
    if not hash then return nil, 'ui.toast.failed' end
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    v = CreateVehicle(hash, at.x, at.y, at.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)
    if v == 0 then return nil, 'ui.toast.failed' end
    SetVehicleOnGroundProperly(v)
    SetVehicleNumberPlateText(v, 'SCOOTEST')
    TaskWarpPedIntoVehicle(ped, v, -1)
    testScooter = v
    return v
end

---Start a test ride with the draft. `push` sends NUI messages (owned by client/scoot/admin.lua).
---@param values table
---@param push fun(action: string, data: table|nil)
---@return boolean|nil started, string|nil errKey
function module.startTest(values, push)
    local v, err = testVehicle()
    if not v then return nil, err end
    preview = nil
    previewSeq = previewSeq + 1
    preview = { vehicle = v, values = values, seq = previewSeq }
    apply(v, values)
    applied[v] = 'preview:' .. previewSeq
    SetVehicleEngineOn(v, true, true, false)
    testing = true
    push('scoot:handling:test', { active = true, key = CFG.ReturnKey, unit = MPH and 'mph' or 'kmh', launch = LAUNCH_TARGET })
    CreateThread(function()
        local top, launchAt, launchTime, lastLaunch = 0.0, nil, nil, nil
        while testing do
            local speed = 0.0
            if DoesEntityExist(v) then speed = GetEntitySpeed(v) * SPEED_FACTOR end
            if speed > top then top = speed end
            if speed < 1.0 then
                launchAt = GetGameTimer()
            elseif launchAt and speed >= LAUNCH_TARGET then
                lastLaunch = (GetGameTimer() - launchAt) / 1000.0
                launchTime = launchTime and math.min(launchTime, lastLaunch) or lastLaunch
                launchAt = nil
            end
            push('scoot:handling:telemetry', { speed = speed, top = top, launch = launchTime, lastLaunch = lastLaunch })
            Wait(CFG.TelemetryMs or 100)
        end
    end)
    return true
end

---End the test ride (the draft stays on the scooter until the panel closes or it is discarded).
function module.stopTest()
    testing = false
end

---Panel closed: drop the draft and remove the test scooter if this module spawned it.
function module.reset()
    testing = false
    module.clearPreview()
    if testScooter and DoesEntityExist(testScooter) then
        local ped = PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == testScooter then
            local c = GetEntityCoords(testScooter)
            SetEntityCoords(ped, c.x + 0.8, c.y, c.z, false, false, false, false)
        end
        DeleteEntity(testScooter)
    end
    testScooter = nil
end

---Drop the draft and remove the test scooter when this resource stops.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then module.reset() end
end)

---Module export: the handling preview and test-ride API.
package.preload['client.scoot.handling'] = function() return module end

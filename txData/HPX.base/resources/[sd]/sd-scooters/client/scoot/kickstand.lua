---Cosmetic folding support. Each client attaches its own non-networked stand
---to nearby streamed scooters; replicated occupancy/motion determines the pose.
local MODEL = joaat('sd_scoot')
local fleet = require 'client.scoot.fleet'
local STAND = joaat('sd_scoot_stand')
local UP = -82.0
local entries, entering = {}, {}
local running, requested = true, false
local animating = {}

---Native bikes lean when parked. Fit the rubber sole to the ground by
---rotating at the same hinge, so it cannot disappear through the pavement.
local function downAngle(v)
    local foundGround = false
    local function clearance(angle)
        local a = math.rad(angle)
        local lowest = 1.0
        for _, x in ipairs({0.005, 0.035}) do
            for _, y in ipairs({-0.039, -0.003}) do
                local z = -0.1345
                local p = GetOffsetFromEntityInWorldCoords(v, 0.128 + x,
                    -0.107 + y * math.cos(a) - z * math.sin(a),
                    -0.247 + y * math.sin(a) + z * math.cos(a))
                local found, ground = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.5, false)
                if found then foundGround = true; lowest = math.min(lowest, p.z - ground) end
            end
        end
        return lowest
    end
    if clearance(0.0) >= 0.001 then return 0.0, foundGround end
    local raised, lowered = -55.0, 0.0
    if clearance(raised) < 0.001 then return raised, foundGround end
    for _ = 1, 8 do
        local middle = (raised + lowered) * 0.5
        if clearance(middle) >= 0.001 then raised = middle else lowered = middle end
    end
    return raised, foundGround
end

---Delete the stand prop for a scooter and forget its entry and any running animation.
---@param v integer vehicle handle
local function remove(v)
    local e = entries[v]
    if e and DoesEntityExist(e.object) then DeleteEntity(e.object) end
    entries[v] = nil
    animating[v] = nil
end

---True when the scooter itself is not drawn (invisible, faded out, attached or body extra off), so its stand should hide too.
---@param v integer vehicle handle
---@return boolean
local function hidden(v)
    return not IsEntityVisible(v) or GetEntityAlpha(v) == 0
        or IsEntityAttached(v) or not IsVehicleExtraTurnedOn(v, 1)
end

---A docked scooter is held upright by the dock, so its stand stays folded.
local function mustRetract(v)
    return GetPedInVehicleSeat(v, -1) ~= 0 or entering[v]
        or GetVehiclePedIsEntering(PlayerPedId()) == v
        or GetEntitySpeed(v) > 0.35 or IsEntityInAir(v)
        or math.abs(GetEntityRoll(v)) > 35.0 or IsEntityDead(v)
        or type(Entity(v).state.sd_scoot_dock) == 'table'
end

---Attach the stand prop to the chassis hinge at the given fold angle and remember that angle.
---@param v integer vehicle handle
---@param e table stand entry
---@param angle number hinge pitch in degrees (UP is folded)
local function attach(v, e, angle)
    AttachEntityToEntity(e.object, v, e.bone,
        0.128, -0.107, -0.247, angle, 0.0, 0.0,
        false, false, false, false, 2, true)
    e.angle = angle
end

---Create the local stand prop for a scooter, starting folded or already lowered to the ground. Requests the model first and retries on a later scan.
---@param v integer vehicle handle
local function spawn(v)
    if not HasModelLoaded(STAND) then
        RequestModel(STAND)
        requested = true
        return
    end
    local p = GetEntityCoords(v)
    local obj = CreateObjectNoOffset(STAND, p.x, p.y, p.z, false, false, false)
    if obj == 0 then return end
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    SetEntityInvincible(obj, true)
    SetEntityLodDist(obj, 45)
    local retract = mustRetract(v)
    local down, groundValid = 0.0, false
    if not retract then down, groundValid = downAngle(v) end
    local angle = retract and UP or down
    local e = {object = obj, bone = GetEntityBoneIndexByName(v, 'chassis'),
        angle = angle, target = angle, from = angle, started = 0, duration = 0,
        down = down, groundChecked = GetGameTimer(), groundValid = groundValid,
        groundPos = GetEntityCoords(v), groundRot = GetEntityRotation(v,2),
        parkedAt = not retract and GetGameTimer() - 250 or nil}
    entries[v] = e
    attach(v, e, angle)
end

---Tracks which scooters any ped is climbing onto, so their stands fold before the rider mounts. Walks the ped pool every 400 ms while a stand is down, otherwise idles at 1 s.
CreateThread(function()
    while running do
        local lowered = false
        for _, e in pairs(entries) do
            if e.target ~= UP then lowered = true break end
        end
        local map = {}
        if lowered then
            local peds = GetGamePool('CPed')
            for i = 1, #peds do
                local v = GetVehiclePedIsEntering(peds[i])
                if v ~= 0 then map[v] = true end
            end
        end
        entering = map
        Wait(lowered and 400 or 1000)
    end
end)

---Streaming: spawns stands for visible scooters within 35 m and removes the rest, releasing the model when none are near. Runs every 500 ms with a scooter near, 1 s otherwise.
CreateThread(function()
    while running do
        local pos, keep = GetEntityCoords(PlayerPedId()), {}
        for _, v in ipairs(fleet.list()) do
            if GetEntityModel(v) == MODEL and #(GetEntityCoords(v) - pos) < 35.0 then
                keep[v] = true
                if not entries[v] and not hidden(v) then spawn(v) end
            end
        end
        for v in pairs(entries) do
            if not keep[v] or not DoesEntityExist(v) or GetEntityModel(v) ~= MODEL then remove(v) end
        end
        if not next(keep) and requested then SetModelAsNoLongerNeeded(STAND); requested = false end
        Wait(fleet.any() and 500 or 1000)
    end
end)

---State: decides fold or lower for each stand, refits the down angle when a parked scooter shifts, and queues moves for the animation loop. Wakes every 100 ms while a stand is moving or down, 300 ms with stands, 1 s with none.
CreateThread(function()
    while running do
        local now = GetGameTimer()
        for v, e in pairs(entries) do
            if not DoesEntityExist(v) or GetEntityModel(v) ~= MODEL or not DoesEntityExist(e.object) then
                remove(v)
            else
                local invisible = hidden(v)
                if invisible ~= e.hidden then SetEntityVisible(e.object, not invisible, false); e.hidden = invisible end
                local retract = invisible or mustRetract(v)
                if retract then e.parkedAt = nil else e.parkedAt = e.parkedAt or now end
                if not retract and now - e.groundChecked > 500 then
                    local pos, rot = GetEntityCoords(v), GetEntityRotation(v,2)
                    if not e.groundValid or #(pos-e.groundPos) > 0.004 or #(rot-e.groundRot) > 0.3 then
                        local down, valid = downAngle(v)
                        if math.abs(down-e.down)>0.4 then e.down=down end
                        e.groundPos,e.groundRot,e.groundValid=pos,rot,valid
                    end
                    e.groundChecked = now
                end
                local target = (retract or now - e.parkedAt < 250) and UP or e.down
                if target ~= e.target then
                    e.from, e.target, e.started = e.angle, target, now
                    e.duration = (target == UP and 220 or 340) * math.abs(target - e.angle) / 82.0
                    animating[v] = e
                end
                if not animating[v] and not IsEntityAttachedToEntity(e.object,v) then attach(v,e,e.angle) end
            end
        end
        local busy = next(animating) ~= nil
        if not busy then
            for _, e in pairs(entries) do
                if e.target ~= UP then busy = true break end
            end
        end
        Wait(busy and 100 or (next(entries) and 300 or 1000))
    end
end)

---Only moving stands need frame-by-frame updates. Parked/occupied stands
---keep their attachment transform while the state loop sleeps.
CreateThread(function()
    while running do
        local now=GetGameTimer()
        for v,e in pairs(animating) do
            if not DoesEntityExist(v) or not DoesEntityExist(e.object) then remove(v)
            else
                local t=math.min(1.0,(now-e.started)/math.max(e.duration,1.0))
                local eased=t*t*(3.0-2.0*t)
                attach(v,e,t>=1.0 and e.target or e.from+(e.target-e.from)*eased)
                if t>=1.0 then animating[v]=nil end
            end
        end
        Wait(next(animating) and 0 or (next(entries) and 50 or 1000))
    end
end)

---Stop the loops, delete every stand and release the model.
local function stop()
    running = false
    for v in pairs(entries) do remove(v) end
    if requested then SetModelAsNoLongerNeeded(STAND); requested = false end
end
---Clean up the stand props when this resource stops.
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then stop() end
end)
---Module export: the stop function and the live stand entries.
package.preload['client.scoot.kickstand'] = function() return {stop = stop, entries = entries} end

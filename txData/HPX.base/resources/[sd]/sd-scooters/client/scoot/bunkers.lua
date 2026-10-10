---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
local fleet = require 'client.scoot.fleet'

---@type table Bunker tuning (configs/shared/bunkers.lua).
local CFG = config.Bunkers
---@type table Dispense timeline + geometry (configs/shared/bunkers.lua > Dispense).
local D = CFG.Dispense
---@type table|nil Lid LED behaviour (configs/shared/bunkers.lua > Lights); nil leaves the lenses dim.
local L = CFG.Lights
---@type table The local ride-out vehicle + stem extras (configs/shared/bunkers.lua > Dispense.Vehicle).
local V = D.Vehicle
---@type string GlobalState key the server publishes the enabled bunkers under.
local STATE_KEY = 'sd_scoot:bunkers'

---@type table<integer, table> lib.points entry per bunker id. Each point carries its own prop
---state: bunker (published row), entity, ground (vector3), cycle (running dispense, or nil).
local points = {}

---@type table<integer, number> Debug holds from /scootlift: bunker id -> metres above ground level.
local lifted = {}

---Where a bunker's body rests between cycles: below ground, or above it while /scootlift holds it.
---@param point table
---@return number z
local function parkedZ(point)
    local extra = lifted[point.bunker.id]
    if extra then return point.ground.z + extra end
    return point.ground.z - CFG.RiseDepth
end

---Ease-in-out (smoothstep), the shape of Blender's default keyframe interpolation.
---@param t number 0..1
---@return number
local function ease(t)
    return t * t * (3.0 - 2.0 * t)
end

---Progress 0..1 of `now` through a { startMs, endMs } window, clamped.
---@param now integer ms since the cycle began
---@param win table { startMs, endMs }
---@return number
local function seg(now, win)
    if now <= win[1] then return 0.0 end
    if now >= win[2] then return 1.0 end
    return (now - win[1]) / (win[2] - win[1])
end

---Create the prop for a bunker, parked below the ground. Runs on point enter, so the world around
---it is loaded and the ground probe normally succeeds; the stored z is the fallback.
---@param point table the lib.points entry
local function spawnProp(point)
    local hash = joaat(CFG.Model)
    local waited = 0
    while not IsModelValid(hash) and waited < 10000 do
        Wait(250)
        waited = waited + 250
    end
    local model = IsModelValid(hash) and lib.requestModel(hash, 5000) or nil
    if not model then
        log.error('bunkers', 'model %s did not load; is stream/%s.ytyp registered?', CFG.Model, CFG.Model)
        return
    end
    local b = point.bunker
    local found, groundZ = GetGroundZFor_3dCoord(b.x, b.y, b.z + 1.0, false)
    point.ground = vec3(b.x, b.y, found and groundZ or b.z)
    local obj = CreateObjectNoOffset(model, point.ground.x, point.ground.y, parkedZ(point), false, false, false)
    SetEntityHeading(obj, b.heading)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    point.entity = obj
end

---Delete every part prop of a running cycle. Idempotent.
---@param cycle table
local function deleteParts(cycle)
    if cycle.undress then cycle.undress(cycle) end
    for _, ent in pairs(cycle.parts) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    cycle.parts = {}
end

---Delete the closed-front parts a /scootlift hold shows. Idempotent.
---@param point table
local function clearClosed(point)
    if not point.closed then return end
    for _, ent in pairs(point.closed) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    point.closed = nil
end

---Delete a point's prop (and any cycle parts) if it has one. Idempotent.
---@param point table
local function despawnProp(point)
    clearClosed(point)
    if point.cycle then deleteParts(point.cycle) end
    point.cycle = nil
    if point.entity and DoesEntityExist(point.entity) then DeleteObject(point.entity) end
    point.entity = nil
end

---A non-networked, collision-free part prop attached to a parent with an offset and rotation.
---@param model string
---@param parent integer entity
---@param off vector3 offset in the parent's space
---@param rot vector3 rotation in degrees
---@return integer|nil entity
local function attachPart(model, parent, off, rot)
    local hash = lib.requestModel(joaat(model), 5000)
    if not hash then
        log.error('bunkers', 'part model %s did not load', model)
        return nil
    end
    local at = GetEntityCoords(parent)
    local ent = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ent, false, false)
    AttachEntityToEntity(ent, parent, 0, off.x, off.y, off.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    return ent
end

---Re-attach a part at a new offset/rotation (attachments are fixed once made).
---@param ent integer
---@param parent integer
---@param off vector3
---@param rot vector3
local function move(ent, parent, off, rot)
    AttachEntityToEntity(ent, parent, 0, off.x, off.y, off.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
end

---Where the deck sits for a given X along its exit path: height and nose pitch as it tips over
---the ramp. Mirrors the Blender keys (frames 150/169/182/201).
---@param x number deck origin X in prop space
---@return number z, number pitchDeg
local function deckPose(x)
    local restZ = D.ScooterRest.z
    if x >= D.RampTopX then return restZ, 0.0 end
    if x >= D.RampBottomX then
        local t = (D.RampTopX - x) / (D.RampTopX - D.RampBottomX)
        return restZ + (D.RampDropZ - restZ) * t, D.RampPitchDeg * t
    end
    if x >= D.RearOnRampX then return D.RampDropZ, D.RampPitchDeg end
    if x >= D.RearDownX then
        local t = (D.RearOnRampX - x) / (D.RearOnRampX - D.RearDownX)
        return D.RampDropZ * (1.0 - t), D.RampPitchDeg * (1.0 - t)
    end
    return 0.0, 0.0
end

---Show exactly one stem pose on a scooter: that extra on, every other flipbook extra off.
---@param veh integer
---@param extraId integer
local function setStemPose(veh, extraId)
    for _, k in ipairs(V.StemPoses) do
        SetVehicleExtra(veh, k, k ~= extraId)
    end
end

---A real scooter only ever shows the riding stem. Extras are owner-controlled and synced by the
---game, so a client that does not own the entity leaves it to the one that does.
---@param veh integer
local function enforceExtras(veh)
    if not DoesEntityExist(veh) or not DoesExtraExist(veh, V.Upright) then return end
    if NetworkGetEntityIsNetworked(veh) and NetworkGetEntityOwner(veh) ~= PlayerId() then return end
    setStemPose(veh, V.Upright)
end

---The scooter that rides out: a local, non-networked copy of the real vehicle in the colour the
---server chose, stem folded, parked in the bay and attached to the bunker like the other parts.
---@param parent integer bunker prop
---@param colour integer Config.Scooters.Colours index
---@return integer|nil vehicle
local function spawnLocalScooter(parent, colour)
    local hash = lib.requestModel(joaat(config.Scooters.Model), 5000)
    if not hash then
        log.error('bunkers', 'vehicle model %s did not load for the dispense', config.Scooters.Model)
        return nil
    end
    local at = GetEntityCoords(parent)
    local veh = CreateVehicle(hash, at.x, at.y, at.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local paint = config.Scooters.Colours[colour] or config.Scooters.Colours[1]
    SetVehicleColours(veh, paint.primary, paint.primary)
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleDoorsLocked(veh, 2)
    SetEntityCollision(veh, false, false)
    SetEntityInvincible(veh, true)
    setStemPose(veh, V.StemPoses[1])
    local r = D.ScooterRest
    AttachEntityToEntity(veh, parent, 0, r.x, r.y, r.z + V.OriginHeight, 0.0, 0.0, V.Yaw, false, false, false, false, 2, true)
    return veh
end

---Dress the ride-out copy with the accessories the order was placed with, so the scooter the player
---watches roll out is the one they bought. The accessory modules load after this file, so they are
---required here rather than at the top.
---@param cycle table
---@param veh integer local scooter
---@param customization table|string|nil
local function dressLocalScooter(cycle, veh, customization)
    if not customization then return end
    local extras = require 'client.scoot.extras'
    local shared = require 'shared.extras'
    local options = shared.decode(customization)
    CreateThread(function()
        if not DoesEntityExist(veh) then return end
        local objects = extras.dress(veh, options)
        if cycle.parts.scooter ~= veh then return extras.undress(objects) end
        cycle.dressed = objects
        if options.rear ~= 'delivery' then return end
        local box = require('client.scoot.storage').dressBox(veh, options.box)
        if cycle.parts.scooter ~= veh then return require('client.scoot.storage').undressBox(box) end
        cycle.box = box
    end)
end

---Delete the accessory props the ride-out copy was dressed with. Idempotent.
---@param cycle table
local function undressLocalScooter(cycle)
    if cycle.dressed then
        require('client.scoot.extras').undress(cycle.dressed)
        cycle.dressed = nil
    end
    if cycle.box then
        require('client.scoot.storage').undressBox(cycle.box)
        cycle.box = nil
    end
end

---Build every moving part in its closed/parked pose, attached to the bunker prop.
---@param point table
---@param colour integer paint the ride-out scooter gets
---@param customization table|string|nil accessories the order was placed with
---@return table|nil cycle
local function buildParts(point, colour, customization)
    local ent = point.entity
    local parts = {}
    local function bail()
        for _, e in pairs(parts) do if DoesEntityExist(e) then DeleteEntity(e) end end
        return nil
    end
    for i = 0, D.Slats - 1 do
        local s = attachPart(D.Models.slat, ent, vec3(0.0, 0.0, i * D.SlatPitch), vec3(0.0, 0.0, 0.0))
        if not s then return bail() end
        parts['slat' .. i] = s
    end
    parts.ramp = attachPart(D.Models.ramp, ent, D.RampHinge, vec3(0.0, 0.0, 0.0))
    parts.pusher = attachPart(D.Models.pusher, ent, vec3(D.PusherRest, 0.0, 0.0), vec3(0.0, 0.0, 0.0))
    if not (parts.ramp and parts.pusher) then return bail() end
    parts.scooter = spawnLocalScooter(ent, colour)
    if not parts.scooter then return bail() end
    if L then
        parts.lights = attachPart(L.Model, ent, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0))
        if parts.lights then SetEntityAlpha(parts.lights, 0, false) end
    end
    local cycle = { parts = parts, started = GetGameTimer(), spawned = false, stemPose = 1, undress = undressLocalScooter }
    dressLocalScooter(cycle, parts.scooter, customization)
    return cycle
end

---The body alone has an open front; the shutter, ramp and pusher only exist during a cycle. While
---/scootlift holds a bunker between cycles, show them in their closed pose so it reads as parked.
---@param point table
local function syncClosed(point)
    local want = lifted[point.bunker.id] and not point.cycle and point.entity and DoesEntityExist(point.entity)
    if not want then return clearClosed(point) end
    if point.closed then return end
    local ent, parts = point.entity, {}
    for i = 0, D.Slats - 1 do
        parts['slat' .. i] = attachPart(D.Models.slat, ent, vec3(0.0, 0.0, i * D.SlatPitch), vec3(0.0, 0.0, 0.0))
    end
    parts.ramp = attachPart(D.Models.ramp, ent, D.RampHinge, vec3(0.0, 0.0, 0.0))
    parts.pusher = attachPart(D.Models.pusher, ent, vec3(D.PusherRest, 0.0, 0.0), vec3(0.0, 0.0, 0.0))
    point.closed = parts
end

---Hide a freshly created dispense vehicle until the props hand over to it.
---@param cycle table
---@param veh integer
local function hideVehicle(cycle, veh)
    cycle.vehicle = veh
    enforceExtras(veh)
    SetEntityVisible(veh, false, false)
    SetEntityCollision(veh, false, false)
    FreezeEntityPosition(veh, true)
end

---Show the vehicle the props were standing in for. Safe to call twice.
---@param cycle table
local function revealVehicle(cycle)
    local veh = cycle.vehicle
    cycle.vehicle = nil
    if not veh or not DoesEntityExist(veh) then return end
    SetEntityVisible(veh, true, false)
    SetEntityCollision(veh, true, true)
    FreezeEntityPosition(veh, false)
    SetVehicleOnGroundProperly(veh)
end

---Find the real scooter the server spawned for this bunker's cycle. The state bag that flags it can
---land after the hand-over is due (first dispense of a session streams the model and the entity), so
---the pool is swept as a fallback rather than trusting the bag alone.
---@param point table
---@return integer|nil vehicle
local function findDispensed(point)
    local now = GetGameTimer()
    if now < (point.nextSweep or 0) then return nil end
    point.nextSweep = now + 150
    local model = joaat(config.Scooters.Model)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and GetEntityModel(veh) == model then
            local flag = Entity(veh).state.sd_scoot_dispense
            if type(flag) == 'table' and flag.bunkerId == point.bunker.id then return veh end
        end
    end
    return nil
end

---Apply the timeline at `now` ms to the bunker prop and its parts.
---@param point table
---@param now integer
local function step(point, now)
    local cycle, ent, g = point.cycle, point.entity, point.ground
    local P = cycle.parts
    local up = ease(seg(now, D.Rise)) * (1.0 - ease(seg(now, D.Sink)))
    SetEntityCoordsNoOffset(ent, g.x, g.y, g.z - CFG.RiseDepth * (1.0 - up), false, false, false)
    if L and P.lights and DoesEntityExist(P.lights) then
        local lit = ease(seg(now, L.FadeIn)) * (1.0 - ease(seg(now, L.FadeOut)))
        SetEntityAlpha(P.lights, math.floor(lit * 255 + 0.5), false)
        local glow = L.Glow
        if glow and lit > 0.0 then
            local c = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, glow.height)
            DrawLightWithRange(c.x, c.y, c.z, glow.colour[1], glow.colour[2], glow.colour[3], glow.range, glow.intensity * lit)
        end
    end
    local lift = D.ShutterLift * (ease(seg(now, D.ShutterOpen)) * (1.0 - ease(seg(now, D.ShutterClose))))
    for i = 0, D.Slats - 1 do
        local s = P['slat' .. i]
        if s and DoesEntityExist(s) then
            local z = i * D.SlatPitch + lift
            move(s, ent, vec3(0.0, 0.0, z), vec3(0.0, 0.0, 0.0))
            SetEntityVisible(s, D.SlatBottom + z < D.HousingBottom, false)
        end
    end
    local rampT = ease(seg(now, D.RampOut)) * (1.0 - ease(seg(now, D.RampIn)))
    move(P.ramp, ent, D.RampHinge, vec3(0.0, D.RampOpenDeg * rampT, 0.0))
    local pushT = ease(seg(now, D.Push)) * (1.0 - ease(seg(now, D.PusherBack)))
    move(P.pusher, ent, vec3(D.PusherRest + (D.PusherOut - D.PusherRest) * pushT, 0.0, 0.0), vec3(0.0, 0.0, 0.0))
    if not cycle.spawned then
        local veh = P.scooter
        if now >= D.SpawnAt then
            local real = cycle.vehicle
            if not real and veh and DoesEntityExist(veh) then
                real = findDispensed(point)
                if real then hideVehicle(cycle, real) end
            end
            if not real and veh and DoesEntityExist(veh) and GetGameTimer() - (cycle.waitFrom or 0) < (V.HandoverGraceMs or 4000) then
                if not cycle.waitFrom then
                    cycle.waitFrom = GetGameTimer()
                    local c, r = GetEntityCoords(veh), GetEntityRotation(veh, 2)
                    DetachEntity(veh, true, true)
                    SetEntityCoordsNoOffset(veh, c.x, c.y, c.z, false, false, false)
                    SetEntityRotation(veh, r.x, r.y, r.z, 2, true)
                    FreezeEntityPosition(veh, true)
                end
                return
            end
            if real and DoesEntityExist(real) and veh and DoesEntityExist(veh) then
                if not cycle.placedAt then
                    cycle.placedAt = GetGameTimer()
                    cycle.handover = { coords = GetEntityCoords(veh), rot = GetEntityRotation(veh, 2) }
                end
                if not cycle.placed and GetGameTimer() >= (cycle.nextPlace or 0) then
                    cycle.nextPlace = GetGameTimer() + 100
                    if NetworkGetEntityOwner(real) == PlayerId() or NetworkRequestControlOfEntity(real) then
                        local c, r = cycle.handover.coords, cycle.handover.rot
                        SetEntityCoordsNoOffset(real, c.x, c.y, c.z, false, false, false)
                        SetEntityRotation(real, r.x, r.y, r.z, 2, true)
                        cycle.placed = true
                    end
                end
                local inPlace = #(GetEntityCoords(real) - cycle.handover.coords) < 0.35
                if inPlace or GetGameTimer() - cycle.placedAt > (V.RevealWaitMs or 1000) then
                    cycle.spawned = true
                    DeleteEntity(veh)
                    P.scooter = nil
                    revealVehicle(cycle)
                end
            else
                cycle.spawned = true
                if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
                P.scooter = nil
                revealVehicle(cycle)
            end
        elseif veh and DoesEntityExist(veh) then
            local n = #V.StemPoses
            local idx = math.min(n, math.floor(seg(now, D.Unfold) * (n - 1) + 0.5) + 1)
            if idx ~= cycle.stemPose then
                cycle.stemPose = idx
                setStemPose(veh, V.StemPoses[idx])
            end
            local push = seg(now, D.Push)
            local coast = seg(now, D.Coast)
            coast = 1.0 - (1.0 - coast) * (1.0 - coast)
            local x = D.ScooterRest.x + (D.ScooterPushed - D.ScooterRest.x) * push + (D.ScooterClear - D.ScooterPushed) * coast
            local z, pitch = deckPose(x)
            move(veh, ent, vec3(x, 0.0, z + V.OriginHeight), vec3(-pitch, 0.0, V.Yaw))
        end
    end
end

---Run one dispense cycle on a bunker's prop, in its own thread.
---@param point table
---@param colour integer paint of the scooter being dispensed
---@param customization table|string|nil accessories the scooter was ordered with
local function runCycle(point, colour, customization)
    if point.cycle or not point.entity or not DoesEntityExist(point.entity) then return end
    clearClosed(point)
    local cycle = buildParts(point, colour, customization)
    if not cycle then
        log.error('bunkers', 'dispense parts failed to build for bunker #%d', point.bunker.id)
        return
    end
    point.cycle = cycle
    CreateThread(function()
        while point.cycle == cycle do
            if not point.entity or not DoesEntityExist(point.entity) then break end
            local now = GetGameTimer() - cycle.started
            step(point, now)
            if now >= D.TotalMs then break end
            Wait(0)
        end
        if point.cycle == cycle then
            deleteParts(cycle)
            point.cycle = nil
            if point.entity and DoesEntityExist(point.entity) then
                local g = point.ground
                SetEntityCoordsNoOffset(point.entity, g.x, g.y, parkedZ(point), false, false, false)
            end
            syncClosed(point)
        end
    end)
end

---Register a lib.points entry for one published bunker.
---@param b table { id, name, x, y, z, heading }
local function addPoint(b)
    local point = lib.points.new({ coords = vec3(b.x, b.y, b.z), distance = CFG.StreamDistance, bunker = b })
    function point:onEnter()
        spawnProp(self)
        syncClosed(self)
    end
    function point:onExit() despawnProp(self) end
    points[b.id] = point
end

---Remove a point and its prop.
---@param id integer
local function removePoint(id)
    local point = points[id]
    if not point then return end
    despawnProp(point)
    point:remove()
    points[id] = nil
end

---Reconcile the local points with the published list. Diffed by id and transform, so an untouched
---bunker never blinks when a different one is added, moved or removed.
---@param list table[]|nil published bunkers
local function build(list)
    list = list or {}
    local seen = {}
    for _, b in ipairs(list) do
        seen[b.id] = true
        local existing = points[b.id]
        if existing then
            local old = existing.bunker
            if old.x ~= b.x or old.y ~= b.y or old.z ~= b.z or old.heading ~= b.heading then
                removePoint(b.id)
            end
        end
        if not points[b.id] then addPoint(b) end
    end
    for id in pairs(points) do
        if not seen[id] then removePoint(id) end
    end
    log.debug('bunkers', 'rebuilt: %d bunker(s)', #list)
end

---The server tells everyone near a station to play its dispense cycle.
---@param bunkerId integer
---@param colour integer Config.Scooters.Colours index of the scooter coming out
---@param customization table|nil accessories the scooter was ordered with
RegisterNetEvent('sd_scoot:client:dispense', function(bunkerId, colour, customization)
    local point = points[tonumber(bunkerId) or -1]
    if not point then return end
    if not point.entity then spawnProp(point) end
    runCycle(point, tonumber(colour) or 1, customization)
end)

---Debug (/scootlift): toggle the nearest streamed bunker between parked underground and held above
---ground. Local to this client; the hold survives the prop streaming out and back in.
---@param height number|nil metres above ground level
RegisterNetEvent('sd_scoot:client:liftBunker', function(height)
    local pos = GetEntityCoords(cache.ped)
    local nearest, best
    for _, point in pairs(points) do
        if point.entity and DoesEntityExist(point.entity) then
            local d = #(pos - point.ground)
            if not best or d < best then nearest, best = point, d end
        end
    end
    if not nearest then
        return lib.notify({ title = locale('notify.title'), description = 'No bunker streamed in nearby', type = 'error' })
    end
    local id = nearest.bunker.id
    if lifted[id] and not height then
        lifted[id] = nil
    else
        lifted[id] = tonumber(height) or 0.0
    end
    if not nearest.cycle then
        local g = nearest.ground
        SetEntityCoordsNoOffset(nearest.entity, g.x, g.y, parkedZ(nearest), false, false, false)
    end
    syncClosed(nearest)
    local msg = lifted[id] and ('Bunker #%d lifted to +%.2fm (%.1fm away)'):format(id, lifted[id], best)
        or ('Bunker #%d lowered'):format(id)
    log.info('bunkers', msg)
    lib.notify({ title = locale('notify.title'), description = msg, type = 'info' })
end)

---Every real scooter carries the `sd_scoot` state bag from creation: the owner makes sure it shows
---the riding stem and none of the fold poses, whatever extras the game rolled at spawn.
AddStateBagChangeHandler('sd_scoot', nil, function(bagName, _, value)
    if not value then return end
    local ent = GetEntityFromStateBagName(bagName)
    local deadline = GetGameTimer() + 3000
    while (ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < deadline do
        Wait(50)
        ent = GetEntityFromStateBagName(bagName)
    end
    if ent ~= 0 and DoesEntityExist(ent) then enforceExtras(ent) end
end)

---Any freshly created scooter (the server flags every sd_scoot on creation, /car included): wait for its
---model to finish loading so the extras exist, then straighten the stem at once. Only the owner can.
AddStateBagChangeHandler('sd_scoot_fresh', nil, function(bagName, _, value)
    if not value or not V then return end
    local deadline = GetGameTimer() + 5000
    local ent = GetEntityFromStateBagName(bagName)
    while GetGameTimer() < deadline do
        if ent ~= 0 and DoesEntityExist(ent) then
            if NetworkGetEntityIsNetworked(ent) and NetworkGetEntityOwner(ent) ~= PlayerId() then return end
            if DoesExtraExist(ent, V.Upright) then break end
            Wait(0)
        else
            Wait(50)
        end
        ent = GetEntityFromStateBagName(bagName)
    end
    if ent ~= 0 and DoesEntityExist(ent) then enforceExtras(ent) end
end)

---Belt and braces for the same rule: the state bag can arrive before the model is streamed (the
---extras do not exist yet) and ownership can migrate, so every networked scooter this client owns
---is re-checked once a second and corrected only when a pose is actually wrong.
CreateThread(function()
    if not V then return end
    local model = joaat(config.Scooters.Model)
    while true do
        Wait(1000)
        for _, veh in ipairs(fleet.all()) do
            if DoesEntityExist(veh) and GetEntityModel(veh) == model and NetworkGetEntityIsNetworked(veh) and NetworkGetEntityOwner(veh) == PlayerId() and DoesExtraExist(veh, V.Upright) then
                local wrong = not IsVehicleExtraTurnedOn(veh, V.Upright)
                if not wrong then
                    for _, k in ipairs(V.StemPoses) do
                        if k ~= V.Upright and IsVehicleExtraTurnedOn(veh, k) then wrong = true break end
                    end
                end
                if wrong then setStemPose(veh, V.Upright) end
            end
        end
    end
end)

---Rebuild the local bunkers whenever the server publishes a new list.
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    build(value)
end)

---A dispensing vehicle arrives flagged with its bunker: keep it out of sight until the props are
---done. The flag flips to false at the swap as a safety net for a client that missed the frame.
AddStateBagChangeHandler('sd_scoot_dispense', nil, function(bagName, _, value)
    local ent = GetEntityFromStateBagName(bagName)
    local deadline = GetGameTimer() + 3000
    while (ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < deadline do
        Wait(50)
        ent = GetEntityFromStateBagName(bagName)
    end
    if ent == 0 or not DoesEntityExist(ent) then return end
    if type(value) == 'table' and value.bunkerId then
        local point = points[value.bunkerId]
        if point and point.cycle and not point.cycle.spawned then
            hideVehicle(point.cycle, ent)
        end
    else
        for _, point in pairs(points) do
            if point.cycle and point.cycle.vehicle == ent then revealVehicle(point.cycle) end
        end
        if not IsEntityVisible(ent) then
            SetEntityVisible(ent, true, false)
            SetEntityCollision(ent, true, true)
            FreezeEntityPosition(ent, false)
        end
    end
end)

---Live model reload (the server's /scootflush): every station prop and local part goes, the
---streamed models are released, and once the game reports them unloaded the stations are rebuilt
---from the freshly restarted sd_scoot_assets. A model still resident (a rented scooter under the
---player, say) is named so the user knows a reconnect is needed for that one.
RegisterNetEvent('sd_scoot:client:flush', function()
    for id in pairs(points) do removePoint(id) end
    local names = { CFG.Model, config.Scooters.Model }
    for _, m in pairs(D.Models) do names[#names + 1] = m end
    if L then names[#names + 1] = L.Model end
    local hashes = {}
    for _, n in ipairs(names) do
        hashes[n] = joaat(n)
        SetModelAsNoLongerNeeded(hashes[n])
    end
    local nudges = config.Admin.FlushNudgeModels or { 'adder', 'zentorno' }
    for _, n in ipairs(nudges) do RequestModel(joaat(n)) end
    local deadline = GetGameTimer() + (config.Admin.FlushWaitMs or 8000)
    local stuck
    repeat
        Wait(250)
        stuck = {}
        for n, h in pairs(hashes) do
            if HasModelLoaded(h) then stuck[#stuck + 1] = n end
        end
    until #stuck == 0 or GetGameTimer() > deadline
    for _, n in ipairs(nudges) do SetModelAsNoLongerNeeded(joaat(n)) end
    table.sort(stuck)
    build(GlobalState[STATE_KEY])
    if #stuck == 0 then
        lib.notify({ title = locale('notify.title'), description = locale('notify.flushed', table.concat(names, ', ')), type = 'success' })
    else
        lib.notify({ title = locale('notify.title'), description = locale('notify.flush_stuck', table.concat(stuck, ', ')), type = 'error' })
    end
    log.info('bunkers', 'flush: %d model(s) released, %d still resident', #names - #stuck, #stuck)
end)

---Build the bunkers already published before this client loaded.
CreateThread(function()
    build(GlobalState[STATE_KEY])
end)

---Remove every bunker point (and its props) when this resource stops.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(points) do removePoint(id) end
end)

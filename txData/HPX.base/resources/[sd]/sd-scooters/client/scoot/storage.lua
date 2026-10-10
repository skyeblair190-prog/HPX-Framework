---Storage box lid. The box body is an ordinary accessory prop (client/scoot/extras.lua); the lid and
---the latch lever are separate local props hinged on the chassis, animated here from the replicated
---`sd_scoot_lid` state so everyone nearby sees the box open. Opening goes through the server, which
---checks the renter and opens the stash.
local config = require 'configs.config'
local extras = require 'shared.extras'
local fleet = require 'client.scoot.fleet'

local CFG = config.Storage
local MODEL = fleet.model
local LEVER = joaat('sdx_delivery_lever')
---Hinge axes in chassis space; each model's origin sits on its own axis.
local LID_AT = vec3(0.0, -0.396, 0.107)
local LEVER_AT = vec3(0.0, -0.739, 0.080)
---Where the box is, for the prompt distance, and its closed bounds for the target aim (chassis space).
local BOX_AT = vec3(0.0, -0.570, 0.080)
local BOX_MIN, BOX_MAX = vec3(-0.150, -0.748, -0.050), vec3(0.150, -0.390, 0.250)
---GTA's own car trunk sounds, played as world audio on the scooter (the game handles distance and
---direction). Only clients this close start them at all.
local SOUND_SET = 'Lowrider_Super_Mod_Garage_Sounds'
local SOUNDS = { ['box-open'] = 'Trunk_Open', ['box-close'] = 'Trunk_Shut' }
local SOUND_RANGE = 25.0
local LID_OPEN, LEVER_OPEN = -96.0, 58.0
local RANGE = 35.0

---@type table<integer, table> vehicle -> { lid, lever, bone, lidAngle, leverAngle, want, anim, hidden }
local entries = {}
---@type table<integer, table> the entries whose lid or lever is moving
local animating = {}
local running = true
---@type table<integer, boolean> model hashes this module asked the streamer for
local requested = {}
---@type table<string, table> decoded customization string -> { box = boolean, colour = string }
local boxCache = {}

---The box a scooter carries, cached per customization string.
---@param v integer
---@return table { box = boolean, colour = string }
local function boxOf(v)
    local state = Entity(v).state.sd_scoot
    if not state then return { box = false, colour = 'stock' } end
    local raw = state.customization
    local key = type(raw) == 'string' and raw or json.encode(raw or {})
    local found = boxCache[key]
    if not found then
        local options = extras.decode(raw)
        found = { box = options.rear == 'delivery', colour = options.box or 'stock' }
        boxCache[key] = found
    end
    return found
end

---Whether a scooter carries the delivery box.
---@param v integer
---@return boolean
local function hasBox(v)
    return boxOf(v).box
end

---The lid model for a band colour: the stock teal lid, or the recoloured one.
---@param colour string|nil
---@return integer hash
local function lidModel(colour)
    return joaat(colour and colour ~= 'stock' and ('sdx_delivery_lid_' .. colour) or 'sdx_delivery_lid')
end

---Whether a scooter should show no box props: invisible, attached, box extra off or mid-dispense.
---@param v integer
---@return boolean
local function hidden(v)
    return not IsEntityVisible(v) or GetEntityAlpha(v) == 0 or IsEntityAttached(v)
        or not IsVehicleExtraTurnedOn(v, 1) or Entity(v).state.sd_scoot_dispense
end

---The lid only shows open on a parked, unridden scooter, whatever the state bag says in between.
---@param v integer
---@return boolean
local function wantsOpen(v)
    return Entity(v).state.sd_scoot_lid == true and GetPedInVehicleSeat(v, -1) == 0 and GetEntitySpeed(v) < 1.0
end

---Attach the lid and lever props to the scooter at their current angles.
---@param v integer scooter
---@param e table entry { lid, lever, bone, lidAngle, leverAngle }
local function place(v, e)
    AttachEntityToEntity(e.lid, v, e.bone, LID_AT.x, LID_AT.y, LID_AT.z, e.lidAngle, 0.0, 0.0, false, false, false, false, 2, true)
    AttachEntityToEntity(e.lever, v, e.bone, LEVER_AT.x, LEVER_AT.y, LEVER_AT.z, e.leverAngle, 0.0, 0.0, false, false, false, false, 2, true)
end

---Create a local, non-colliding, invincible prop at the scooter for the box parts.
---@param hash integer
---@param v integer
---@return integer object handle (0 when it could not be created)
local function create(hash, v)
    local p = GetEntityCoords(v)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    if obj == 0 then return 0 end
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    SetEntityInvincible(obj, true)
    SetEntityLodDist(obj, 45)
    return obj
end

---Delete the lid and lever props for a scooter and forget its entry and animation.
---@param v integer vehicle handle
local function remove(v)
    local e = entries[v]
    if e then
        if DoesEntityExist(e.lid) then DeleteEntity(e.lid) end
        if DoesEntityExist(e.lever) then DeleteEntity(e.lever) end
    end
    entries[v], animating[v] = nil, nil
end

---Create and attach the lid and lever props, posed open or shut to match the current state. Requests the models first and retries on a later scan.
---@param v integer vehicle handle
local function spawn(v)
    local colour = boxOf(v).colour
    local lidHash = lidModel(colour)
    if not HasModelLoaded(lidHash) or not HasModelLoaded(LEVER) then
        RequestModel(lidHash); RequestModel(LEVER)
        requested[lidHash], requested[LEVER] = true, true
        return
    end
    local lid, lever = create(lidHash, v), create(LEVER, v)
    if lid == 0 or lever == 0 then
        if lid ~= 0 then DeleteEntity(lid) end
        if lever ~= 0 then DeleteEntity(lever) end
        return
    end
    local open = wantsOpen(v)
    local e = { lid = lid, lever = lever, colour = colour, bone = GetEntityBoneIndexByName(v, 'chassis'),
        lidAngle = open and LID_OPEN or 0.0, leverAngle = open and LEVER_OPEN or 0.0, want = open }
    entries[v] = e
    place(v, e)
end

---Smoothstep easing.
---@param t number 0..1
---@return number
local function smooth(t) return t * t * (3.0 - 2.0 * t) end
---Clamp a value to 0..1.
---@param t number
---@return number
local function clamp01(t) return t < 0.0 and 0.0 or (t > 1.0 and 1.0 or t) end
---Ease out with a small overshoot: the lid swings past its stop and settles back, like a real hinge stop.
local function settle(t) local u = t - 1.0; return 1.0 + 1.8 * u * u * u + 0.8 * u * u end

---Pose of a running open/close animation, started from wherever the lid and lever were.
---@param a table { open, started, lid0, lever0 }
---@param elapsed number ms
---@return number lidAngle
---@return number leverAngle
---@return boolean done
local function pose(a, elapsed)
    if a.open then
        local leverMs = math.max(1.0, 240.0 * (LEVER_OPEN - a.lever0) / LEVER_OPEN)
        local lidMs = math.max(1.0, 1150.0 * (a.lid0 - LID_OPEN) / -LID_OPEN)
        local lever = a.lever0 + (LEVER_OPEN - a.lever0) * smooth(clamp01(elapsed / leverMs))
        local t = clamp01((elapsed - leverMs) / lidMs)
        local lid = a.lid0 + (LID_OPEN - a.lid0) * settle(t)
        return lid, lever, elapsed >= leverMs + lidMs
    end
    local lidMs = math.max(1.0, 620.0 * a.lid0 / LID_OPEN)
    local bounceMs = a.lid0 < -8.0 and 170.0 or 0.0
    local leverMs = math.max(1.0, 220.0 * a.lever0 / LEVER_OPEN)
    local t = clamp01(elapsed / lidMs)
    local lid = a.lid0 * (1.0 - t * t)
    if bounceMs > 0.0 and elapsed > lidMs and elapsed < lidMs + bounceMs then
        lid = -1.6 * math.sin((elapsed - lidMs) / bounceMs * math.pi)
    end
    local leverStart = lidMs + bounceMs * 0.6
    local lever = a.lever0 * (1.0 - smooth(clamp01((elapsed - leverStart) / leverMs)))
    return lid, lever, elapsed >= math.max(lidMs + bounceMs, leverStart + leverMs)
end

---Streaming: props for scooters with a box within RANGE metres.
CreateThread(function()
    while running do
        local pos, keep = GetEntityCoords(PlayerPedId()), {}
        for _, v in ipairs(fleet.list()) do
            if GetEntityModel(v) == MODEL and #(GetEntityCoords(v) - pos) < RANGE and hasBox(v) and not hidden(v) then
                keep[v] = true
                local e = entries[v]
                if e and e.colour ~= boxOf(v).colour then remove(v); e = nil end
                if not e then spawn(v) end
            end
        end
        for v in pairs(entries) do
            if not keep[v] or not DoesEntityExist(v) then remove(v) end
        end
        if not next(entries) and not next(keep) and next(requested) then
            for hash in pairs(requested) do SetModelAsNoLongerNeeded(hash) end
            requested = {}
        end
        Wait(fleet.any() and 500 or 1000)
    end
end)

---Play a lid sound from the scooter for this client. Every nearby client animates the lid itself, so
---each plays it locally rather than as a networked sound.
---@param v integer
---@param name 'box-open'|'box-close'
local function sound(v, name)
    if #(GetFinalRenderedCamCoord() - GetEntityCoords(v)) >= SOUND_RANGE then return end
    PlaySoundFromEntity(-1, SOUNDS[name], v, SOUND_SET, false, 0)
end

---Start the lid moving towards its wanted pose. Sounds follow the lid for everyone nearby: the
---open sound as the latch flips, the close sound the moment the lid lands on the seal.
---@param v integer
---@param e table
---@param now integer
---@param lidState any the replicated lid value to judge by (the change handler passes the new one)
local function evaluate(v, e, now, lidState)
    local want = lidState == true and GetPedInVehicleSeat(v, -1) == 0 and GetEntitySpeed(v) < 1.0
    if want == e.want then return end
    e.want = want
    e.anim = { open = want, started = now, lid0 = e.lidAngle, lever0 = e.leverAngle }
    if want then
        sound(v, 'box-open')
    elseif e.lidAngle < -3.0 then
        e.anim.soundAt = now + math.max(1.0, 620.0 * e.lidAngle / LID_OPEN)
    end
    animating[v] = e
end

---A lid change starts moving on the frame the state bag arrives, not on the next poll.
AddStateBagChangeHandler('sd_scoot_lid', '', function(bagName, _, value)
    local v = GetEntityFromStateBagName(bagName)
    local e = v ~= 0 and entries[v]
    if e then evaluate(v, e, GetGameTimer(), value) end
end)

---State: catch a scooter ridden off with its lid up; re-seat props the game detached.
CreateThread(function()
    while running do
        local now = GetGameTimer()
        for v, e in pairs(entries) do
            if not DoesEntityExist(v) or not DoesEntityExist(e.lid) or not DoesEntityExist(e.lever) then
                remove(v)
            else
                evaluate(v, e, now, Entity(v).state.sd_scoot_lid)
                if not animating[v] and (not IsEntityAttachedToEntity(e.lid, v) or not IsEntityAttachedToEntity(e.lever, v)) then
                    place(v, e)
                end
            end
        end
        Wait(next(animating) and 50 or (next(entries) and 150 or 1000))
    end
end)

---Per frame only while a lid or lever is moving.
CreateThread(function()
    while running do
        local now = GetGameTimer()
        for v, e in pairs(animating) do
            if not DoesEntityExist(v) or not DoesEntityExist(e.lid) then
                animating[v] = nil
            else
                local a = e.anim
                if a.soundAt and now >= a.soundAt then a.soundAt = nil; sound(v, 'box-close') end
                local lid, lever, done = pose(a, now - a.started)
                e.lidAngle, e.leverAngle = lid, lever
                place(v, e)
                if done and not a.soundAt then animating[v] = nil end
            end
        end
        Wait(next(animating) and 0 or (next(entries) and 50 or 1000))
    end
end)

---Whether the local player (renter or box admin) can open this scooter's box: on foot, parked and unridden.
---@param v integer
---@return boolean the local player rents this scooter and could open its box right now
local function mine(v)
    if cache.vehicle or not hasBox(v) or hidden(v) then return false end
    local state = Entity(v).state.sd_scoot
    return state ~= nil and (LocalPlayer.state.sd_scoot_rental == state.id or LocalPlayer.state.sd_scoot_box_admin)
        and GetPedInVehicleSeat(v, -1) == 0 and GetEntitySpeed(v) < 1.0
end

---True while this player's own box can be opened: lid down, standing at it.
---@param v integer
---@return boolean
local function canOpen(v)
    if not mine(v) or Entity(v).state.sd_scoot_lid == true then return false end
    local at = GetOffsetFromEntityInWorldCoords(v, BOX_AT.x, BOX_AT.y, BOX_AT.z)
    return #(GetEntityCoords(cache.ped) - at) <= CFG.Distance
end

---Does the camera's aim pass through the box? The box props have no collision, so ox_target's own
---raycast goes straight through them; this tests the aim ray against the box's real bounds instead
---(in the scooter's own space, so any heading or lean works).
---@param v integer
---@return boolean
local function aimedAt(v)
    local cam, rot = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dx, dy, dz = -math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx)
    local o = GetOffsetFromEntityGivenWorldCoords(v, cam.x, cam.y, cam.z)
    local p = GetOffsetFromEntityGivenWorldCoords(v, cam.x + dx, cam.y + dy, cam.z + dz)
    local pad = CFG.TargetPadding
    local near, far = 0.0, 10.0
    for axis = 1, 3 do
        local origin, dir = o[axis], p[axis] - o[axis]
        local lo, hi = BOX_MIN[axis] - pad, BOX_MAX[axis] + pad
        if math.abs(dir) < 1e-6 then
            if origin < lo or origin > hi then return false end
        else
            local t1, t2 = (lo - origin) / dir, (hi - origin) / dir
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > near then near = t1 end
            if t2 < far then far = t2 end
            if near > far then return false end
        end
    end
    return true
end

---ox_inventory's trunk animation: a hand-on-the-lid idle while the stash is open. Closing just lets go.
local OPEN_ANIM = { dict = 'anim@heists@prison_heiststation@cop_reactions', name = 'cop_b_idle' }
---@type integer|nil the scooter whose box this player has open
local looking

---Turn the player to face the box, then play the open anim if they are still looking at it.
---@param v integer
local function playOpenAnim(v)
    local at = GetOffsetFromEntityInWorldCoords(v, BOX_AT.x, BOX_AT.y, BOX_AT.z)
    TaskTurnPedToFaceCoord(cache.ped, at.x, at.y, at.z, 400)
    SetTimeout(200, function()
        if looking ~= v then return end
        lib.requestAnimDict(OPEN_ANIM.dict)
        TaskPlayAnim(cache.ped, OPEN_ANIM.dict, OPEN_ANIM.name, 3.0, 3.0, -1, 49, 0.0, false, false, false)
        RemoveAnimDict(OPEN_ANIM.dict)
    end)
end

---Release the hand-on-lid idle animation.
local function stopOpenAnim()
    StopAnimTask(cache.ped, OPEN_ANIM.dict, OPEN_ANIM.name, 2.0)
end

---Let go of the lid once the box this player opened shuts, however it shut.
CreateThread(function()
    while running do
        if looking then
            if not DoesEntityExist(looking) or Entity(looking).state.sd_scoot_lid ~= true then
                looking = nil
                stopOpenAnim()
            end
            Wait(100)
        else
            Wait(500)
        end
    end
end)

local busy = false
---Open storage: the server lifts the lid and opens the stash; closing the stash drops the lid again.
---@param v integer
local function openStorage(v)
    if busy or not DoesEntityExist(v) then return end
    busy = true
    local called, ok, err = pcall(lib.callback.await, 'sd_scoot:server:storage', false, NetworkGetNetworkIdFromEntity(v))
    busy = false
    if not called then return end
    if ok then
        looking = v
        playOpenAnim(v)
    elseif err then
        lib.notify({ title = locale('notify.title'), description = locale(err), type = 'error' })
    end
end

---The server shuts a box whose viewer walked off or rode away; take the stash window down with it.
RegisterNetEvent('sd_scoot:client:storage:closeInventory', function()
    if GetResourceState('ox_inventory') == 'started' then pcall(function() exports.ox_inventory:closeInventory() end) end
end)

local targeted = false
local OPTION = 'sd_scoot:storage:open'
---@type integer|nil the box the aim was last found on, for onSelect
local aimed

---Add the global ox_target option for opening a rented scooter's box, once, when storage is on and ox_target is running.
local function registerTarget()
    if targeted or not CFG.Enabled or GetResourceState('ox_target') ~= 'started' then return end
    exports.ox_target:addGlobalOption({
        {
            name = OPTION,
            icon = 'fa-solid fa-box-open',
            label = locale('notify.storage_open'),
            canInteract = function()
                if cache.vehicle or not (LocalPlayer.state.sd_scoot_rental or LocalPlayer.state.sd_scoot_box_admin) then return false end
                for v in pairs(entries) do
                    if canOpen(v) and aimedAt(v) then aimed = v return true end
                end
                return false
            end,
            onSelect = function() if aimed then openStorage(aimed) end end,
        },
    })
    targeted = true
end

---Text-prompt fallback for servers without ox_target: standing at your own rented scooter's box.
CreateThread(function()
    Wait(1000)
    registerTarget()
    local shown = false
    while running do
        local wait = 1000
        if not targeted and CFG.Enabled and (LocalPlayer.state.sd_scoot_rental or LocalPlayer.state.sd_scoot_box_admin) and not cache.vehicle then
            local found
            for v in pairs(entries) do
                if canOpen(v) then found = v break end
            end
            if found then
                wait = 0
                if not shown then lib.showTextUI(locale('notify.storage_prompt'), { position = 'left-center', icon = 'box-open' }); shown = true end
                if IsControlJustReleased(0, CFG.PromptKey) then openStorage(found) end
            else
                if shown then lib.hideTextUI(); shown = false end
                wait = next(entries) and 250 or 1000
            end
        elseif shown then
            lib.hideTextUI(); shown = false
        end
        Wait(wait)
    end
end)

---Register the target option again when ox_target (re)starts after this resource.
AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_target' then targeted = false; registerTarget() end
end)

---Clean up on stop: release the animation, delete props, unload models and remove the target option.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    running = false
    if looking then StopAnimTask(cache.ped, OPEN_ANIM.dict, OPEN_ANIM.name, 2.0) end
    for v in pairs(entries) do remove(v) end
    for hash in pairs(requested) do SetModelAsNoLongerNeeded(hash) end
    if targeted and GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeGlobalOption(OPTION) end)
    end
end)

---Hang a shut lid and lever on a scooter the box loop skips (the bunker's local dispense copy), so
---an ordered storage box rides out closed rather than as a bare shell. Requests models, so call it
---in a thread.
---@param v integer vehicle handle
---@param colour string|nil band colour id; nil or 'stock' keeps the teal lid
---@return table|nil parts { lid, lever }
local function dressBox(v, colour)
    if not DoesEntityExist(v) then return nil end
    local lidHash = lidModel(colour)
    if not lib.requestModel(lidHash, 3000) or not lib.requestModel(LEVER, 3000) then return nil end
    requested[lidHash], requested[LEVER] = true, true
    local lid, lever = create(lidHash, v), create(LEVER, v)
    if lid == 0 or lever == 0 then
        if lid ~= 0 then DeleteEntity(lid) end
        if lever ~= 0 then DeleteEntity(lever) end
        return nil
    end
    local parts = { lid = lid, lever = lever, bone = GetEntityBoneIndexByName(v, 'chassis'), lidAngle = 0.0, leverAngle = 0.0 }
    place(v, parts)
    return parts
end

---Delete the props `dressBox` created.
---@param parts table|nil { lid, lever }
local function undressBox(parts)
    if not parts then return end
    if DoesEntityExist(parts.lid) then DeleteEntity(parts.lid) end
    if DoesEntityExist(parts.lever) then DeleteEntity(parts.lever) end
end

---Module export: the live box prop entries and the one-off dressing helpers.
package.preload['client.scoot.storage'] = function() return { entries = entries, dressBox = dressBox, undressBox = undressBox } end

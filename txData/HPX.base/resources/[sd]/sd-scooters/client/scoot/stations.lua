---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
local fleet = require 'client.scoot.fleet'

---@type table Station tuning (configs/shared/stations.lua).
local CFG = config.Stations
---@type table|nil Per-slot point light (configs/shared/stations.lua > Glow); nil leaves the lenses unlit.
local G = CFG.Glow
---@type table Dock prompt tuning (configs/shared/stations.lua > Dock).
local DOCK = CFG.Dock
---@type table Pillar screen tuning (configs/shared/stations.lua > Screen).
local SCREEN = CFG.Screen
---@type table Rental tuning: the dock distance the server enforces (configs/shared/rentals.lua).
local R = config.Rentals
---@type string GlobalState key the server publishes the enabled stations under.
local STATE_KEY = 'sd_scoot:stations'
---@type number How far (m) a player must be for the slot glow to be drawn at all.
local GLOW_RANGE = 40.0
---@type string Runtime texture dictionary + texture the DUI is rendered into.
local DUI_TXD, DUI_TXN = 'sd_scoot_charger_dui', 'screen'

---@type table<integer, table> lib.points entry per station id. Each point carries its own prop
---state: station (published row), entity, lights, lenses (slot -> { entity, kind }), ground.
local points = {}
---@type integer Vehicle model hash a dock accepts.
local SCOOTER = joaat(config.Scooters.Model)
---@type table|nil Point the dock prompt currently shows for.
local prompt = nil
---@type boolean True while a dock request is in flight.
local docking = false
---@type table DUI state: handle, and the last payload sent so unchanged frames are skipped.
local dui = { handle = nil, ready = false, last = nil }

---Load a model or log why it could not be. On a fresh join the ytyps can still be mounting when
---the first point fires, so an archetype that is not valid yet is waited for rather than thrown on.
---@param name string
---@return integer|nil hash
local function model(name)
    local hash = joaat(name)
    local waited = 0
    while not IsModelValid(hash) and waited < 10000 do
        Wait(250)
        waited = waited + 250
    end
    if not IsModelValid(hash) then
        log.error('stations', 'model %s is not registered; is stream/%s.ytyp mounted?', name, CFG.Model)
        return nil
    end
    return lib.requestModel(hash, 5000)
end

---A non-networked, collision-free prop attached to the station base at an offset in its space.
---@param name string model name
---@param parent integer base entity
---@param off vector3
---@return integer|nil entity
local function attached(name, parent, off)
    local hash = model(name)
    if not hash then return nil end
    local pos = GetEntityCoords(parent)
    local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, parent, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    return obj
end

---Delete an entity if it still exists. Idempotent.
---@param ent integer|nil
local function drop(ent)
    if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
end

---How many docks a published station has; rows published before the count existed get the default.
---@param st table
---@return integer
local function dockCount(st)
    return st.count or CFG.Slots
end

---The paint a published station wears; stations published before the palette get the default.
---@param st table
---@return integer
local function stationColour(st)
    return st.colour or CFG.DefaultColour or 1
end

---A frozen, collidable prop standing in a base entity's space: the dock cells and the rail's end
---cap. Not attached, so the game keeps their collision; they are dropped with the base.
---@param name string model
---@param parent integer base entity
---@param off vector3 offset in the base's space
---@return integer|nil entity
---@param heading number station heading in degrees. The offset is rotated by it rather than read
---back off the base entity: an object created this tick still reports its creation rotation, so
---reading the parent places every child unrotated whenever no model load yields first.
local function standing(name, parent, off, heading)
    local hash = model(name)
    if not hash then return nil end
    local h = heading or GetEntityHeading(parent)
    local r = math.rad(h)
    local c, s = math.cos(r), math.sin(r)
    local base = GetEntityCoords(parent)
    local obj = CreateObjectNoOffset(hash, base.x + off.x * c - off.y * s, base.y + off.x * s + off.y * c, base.z + off.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(obj, h)
    FreezeEntityPosition(obj, true)
    return obj
end

---@type fun(point: table, slot: integer, open: boolean) Defined further down with the arm tweens.
local setHoop

---What an occupied slot's light should say: 'full' once topped up, 'charging' while the battery is
---actually rising, otherwise 'idle' (connected, waiting for a charge to be bought).
---@param state table published slot { full, battery, target }
---@return string
local function chargeState(state)
    if state.full then return 'full' end
    local B = config.Battery
    if not B.Enabled then return 'idle' end
    if B.Paid and B.Paid.Enabled then
        return (state.target and state.battery and state.target > state.battery) and 'charging' or 'idle'
    end
    return 'charging'
end

---Bring the slot lenses in line with the published slot table: create, swap or delete per slot.
---@param point table
local function applySlots(point)
    if not point.entity or not DoesEntityExist(point.entity) then return end
    point.lenses = point.lenses or {}
    for slot = 1, dockCount(point.station) do
        local state = point.station.slots and point.station.slots[slot] or false
        local have = point.lenses[slot]
        local want = state and chargeState(state) or nil
        if have and (not want or have.kind ~= want) then
            drop(have.entity)
            point.lenses[slot] = nil
            have = nil
        end
        if want and not have then
            local ent = attached(CFG.LensModels[want] or CFG.LensModels.charging, point.entity, vec3(CFG.SlotX[slot] + CFG.LensOffset.x, CFG.LensOffset.y, CFG.LensOffset.z))
            if ent then point.lenses[slot] = { entity = ent, kind = want } end
        end
        if not state then setHoop(point, slot, true) end
    end
end

---@type table Dock animation timings (configs/shared/stations.lua > Anim).
local ANIM = CFG.Anim
---@type table<integer, table> Hoops that are between lifted and dropped: entity -> tween.
local movingHoops = {}

---Smoothstep ease for the tweens.
---@param t number 0..1
---@return number
local function ease(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

---Re-pin a swing arm to its station at an opening angle. The left arm swings +angle, the right
---arm is the same prop turned 180 degrees and swings -angle, so both bars sweep toward the rail.
---@param hoop table { entity, parent, slot, side }
---@param angle number degrees open (0 = shut over the tyre)
local function pinHoop(hoop, angle)
    if not DoesEntityExist(hoop.entity) or not DoesEntityExist(hoop.parent) then return end
    local x = CFG.SlotX[hoop.slot] + CFG.HoopPivot.x + hoop.side * CFG.HoopSpread
    local rot = hoop.side < 0 and angle or (180.0 - angle)
    AttachEntityToEntity(hoop.entity, hoop.parent, 0, x, CFG.HoopPivot.y, CFG.HoopPivot.z, 0.0, 0.0, rot, false, false, false, false, 2, true)
    hoop.angle = angle
end

---Swing a dock's arms open or shut over Anim.Hoop ms. Retargeting mid-swing carries on from
---where they are.
---@param point table
---@param slot integer
---@param open boolean
function setHoop(point, slot, open)
    local arms = point.hoops and point.hoops[slot]
    if not arms then return end
    local target = open and CFG.HoopOpen or 0.0
    for _, hoop in ipairs(arms) do
        if hoop.angle ~= target or movingHoops[hoop.entity] then
            movingHoops[hoop.entity] = { hoop = hoop, from = hoop.angle or 0.0, to = target, start = GetGameTimer() }
        end
    end
end

---Drive every moving hoop; sleeps while none move.
CreateThread(function()
    while true do
        if next(movingHoops) then
            local now = GetGameTimer()
            for ent, tw in pairs(movingHoops) do
                local t = (now - tw.start) / ANIM.Hoop
                pinHoop(tw.hoop, tw.from + (tw.to - tw.from) * ease(t))
                if t >= 1.0 or not DoesEntityExist(ent) then movingHoops[ent] = nil end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---The colour swatches the screen paints next to each plate: index -> hex.
---@return table<integer, string>
local function colourMap()
    local out = {}
    for i, c in ipairs(config.Scooters.Colours) do out[i] = c.hex end
    return out
end

---@type fun() Defined below ensureDui; forward-declared so the two can call each other.
local sendScreenConfig

---Create the DUI once and route it into the model's screen texture. Done lazily on the first
---station that streams in, so players who never see one never pay for a browser.
local function ensureDui()
    if dui.handle then return end
    dui.handle = CreateDui(('nui://%s/%s'):format(cache.resource, SCREEN.Page), SCREEN.Width, SCREEN.Height)
    local txd = CreateRuntimeTxd(DUI_TXD)
    CreateRuntimeTextureFromDuiHandle(txd, DUI_TXN, GetDuiHandle(dui.handle))
    AddReplaceTexture(SCREEN.Txd, SCREEN.Txn, DUI_TXD, DUI_TXN)
    dui.ready = true
    dui.last = nil
    sendScreenConfig()
end

---Push the static part of the page state: colours, prices and charging rules. Sent once the
---browser reports loaded and again whenever the page itself says it is ready, because a message
---sent before the page has run its script is simply lost.
function sendScreenConfig()
    if not dui.handle then return end
    local waited = 0
    while not IsDuiAvailable(dui.handle) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    local B = config.Battery
    local P = B.Paid or {}
    SendDuiMessage(dui.handle, json.encode({
        colours = colourMap(),
        pricing = { unlock = R.UnlockFee, currency = R.Currency },
        payment = { methods = SCREEN.Payment and SCREEN.Payment.Methods or { R.Account } },
        charging = {
            paid = B.Enabled and P.Enabled == true,
            pricePerPercent = P.PricePerPercent or 0,
            minimumFee = P.MinimumFee or 0,
            step = P.Step or 5,
            presets = P.Presets or { 50, 75, 100 },
            perMinute = B.ChargePerMinute,
            drainPerMinute = B.DrainPerMinute,
            minToRent = B.MinToRent,
            fullAt = B.FullAt,
        },
        brightness = SCREEN.Brightness or 1.0,
        wakeMs = SCREEN.WakeMs or 120000,
    }))
end

---Tear the DUI down and give the model its baked screen back.
local function destroyDui()
    if not dui.handle then return end
    RemoveReplaceTexture(SCREEN.Txd, SCREEN.Txn)
    DestroyDui(dui.handle)
    dui.handle, dui.ready, dui.last = nil, false, nil
end

---The screen follows whichever streamed station is closest inside Screen.Range; further away it
---idles on the logo. Pushes only when the shown state actually changed.
local function refreshScreen()
    if not dui.ready then return end
    local here = GetEntityCoords(cache.ped)
    local best, bestD = nil, SCREEN.Range
    for _, point in pairs(points) do
        if point.entity then
            local d = #(here - point.coords)
            if d <= bestD then best, bestD = point, d end
        end
    end
    local payload
    if best then
        local st = best.station
        local free = 0
        for i = 1, dockCount(st) do
            if not (st.slots and st.slots[i]) then free = free + 1 end
        end
        payload = { station = { name = st.name, slots = st.slots or {}, free = free }, time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) }
    else
        payload = { station = false }
    end
    local encoded = json.encode(payload)
    if encoded == dui.last then return end
    dui.last = encoded
    SendDuiMessage(dui.handle, encoded)
end

---Create the props for a station. Runs on point enter, so the ground probe normally succeeds;
---the stored z is the fallback.
---@param point table
local function spawnProps(point)
    local hash = model(CFG.Model)
    if not hash then return end
    local st = point.station
    local found, groundZ = GetGroundZFor_3dCoord(st.x, st.y, st.z + 1.0, false)
    point.ground = vec3(st.x, st.y, found and groundZ or st.z)
    local obj = CreateObjectNoOffset(hash, point.ground.x, point.ground.y, point.ground.z, false, false, false)
    SetEntityHeading(obj, st.heading)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    point.entity = obj
    point.lights = CFG.LightsModel and attached(CFG.LightsModel, obj, vec3(0.0, 0.0, 0.0)) or nil
    local colour = stationColour(st)
    point.totemShell = CFG.TotemShellModel and standing(CFG.TotemShellModel:format(colour), obj, vec3(0.0, 0.0, 0.0), st.heading) or nil
    local count = dockCount(st)
    point.docks = {}
    point.shells = {}
    for slot = 1, count do
        local dockModel = type(CFG.DockModel) == 'table' and CFG.DockModel[slot] or CFG.DockModel
        point.docks[slot] = standing(dockModel, obj, vec3(CFG.SlotX[slot], 0.0, 0.0), st.heading)
        if CFG.ShellModel then
            point.shells[slot] = standing(CFG.ShellModel:format(colour), obj, vec3(CFG.SlotX[slot], 0.0, 0.0), st.heading)
        end
    end
    point.cap = standing(CFG.EndModel, obj, vec3(CFG.RailStart + CFG.DockPitch * count, 0.0, 0.0), st.heading)
    point.hoops = {}
    for slot = 1, CFG.HoopModel and count or 0 do
        local arms = {}
        for _, side in ipairs({ -1, 1 }) do
            local ent = attached(CFG.HoopModel, obj, vec3(CFG.SlotX[slot] + CFG.HoopPivot.x + side * CFG.HoopSpread, CFG.HoopPivot.y, CFG.HoopPivot.z))
            if ent then
                local hoop = { entity = ent, parent = obj, slot = slot, side = side, angle = 0.0 }
                pinHoop(hoop, (point.station.slots and point.station.slots[slot]) and 0.0 or CFG.HoopOpen)
                arms[#arms + 1] = hoop
            end
        end
        point.hoops[slot] = arms
    end
    applySlots(point)
    ensureDui()
end

---Delete a point's props. Idempotent.
---@param point table
local function despawnProps(point)
    for _, lens in pairs(point.lenses or {}) do drop(lens.entity) end
    point.lenses = {}
    for _, arms in pairs(point.hoops or {}) do
        for _, hoop in ipairs(arms) do
            movingHoops[hoop.entity] = nil
            drop(hoop.entity)
        end
    end
    point.hoops = {}
    for _, dock in pairs(point.docks or {}) do drop(dock) end
    point.docks = {}
    for _, shell in pairs(point.shells or {}) do drop(shell) end
    point.shells = {}
    drop(point.totemShell)
    point.totemShell = nil
    drop(point.cap)
    point.cap = nil
    drop(point.lights)
    point.lights = nil
    drop(point.entity)
    point.entity = nil
end

---Per-frame glow for the occupied slots while the player is close enough to see it.
---@param point table
local function drawGlow(point)
    if not G or not point.entity or not DoesEntityExist(point.entity) then return end
    local breath = 1.0
    if G.PulseMs then
        local phase = (GetGameTimer() % G.PulseMs) / G.PulseMs
        local min = G.PulseMin or 0.35
        breath = min + (1.0 - min) * (0.5 - 0.5 * math.cos(phase * 2.0 * math.pi))
    end
    for slot, lens in pairs(point.lenses or {}) do
        local c = G[lens.kind] or G.charging
        local p = GetOffsetFromEntityInWorldCoords(point.entity, CFG.SlotX[slot] + CFG.LensOffset.x, CFG.LensOffset.y - 0.15, CFG.LensOffset.z + 0.05)
        DrawLightWithRange(p.x, p.y, p.z, c[1], c[2], c[3], G.range, G.intensity * (lens.kind == 'charging' and breath or 1.0))
    end
end

---Free docks of a published station.
---@param st table
---@return integer
local function freeSlots(st)
    local n = 0
    for i = 1, dockCount(st) do
        if not (st.slots and st.slots[i]) then n = n + 1 end
    end
    return n
end

---Whether the player is driving a scooter right now. Any sd_scoot fits a dock: a rented one ends
---its ride, an idle or flat fleet one is parked, and one the fleet never spawned is adopted.
---@return boolean
local function drivingScooter()
    return cache.vehicle ~= false and cache.seat == -1 and GetEntityModel(cache.vehicle) == SCOOTER
end

---Hide the dock prompt if it is up.
local function hidePrompt()
    if not prompt then return end
    prompt = nil
    lib.hideTextUI()
end

---Show (or refresh) the dock prompt for a station.
---@param point table
local function showPrompt(point)
    local st = point.station
    local free = freeSlots(st)
    local text = free > 0 and locale('notify.dock_prompt', st.name, free, dockCount(st)) or locale('notify.dock_full', st.name)
    if prompt and prompt.point == point and prompt.text == text then return end
    prompt = { point = point, text = text, free = free }
    lib.showTextUI(text, { position = 'left-center', icon = 'charging-station' })
end

---Step off the scooter and ask the server to park it in the nearest free slot. The server decides
---what that means for the scooter (end the ride, park it, or adopt it) and enforces distance.
local function dock()
    if docking or not cache.vehicle then return end
    docking = true
    hidePrompt()
    local ped, veh = cache.ped, cache.vehicle
    local netId = NetworkGetNetworkIdFromEntity(veh)
    TaskLeaveVehicle(ped, veh, 0)
    local waited = 0
    while IsPedInAnyVehicle(ped, false) and waited < 2500 do
        Wait(100)
        waited = waited + 100
    end
    local reply = lib.callback.await('sd_scoot:server:stations:dock', false, netId)
    if type(reply) == 'table' and reply.success and reply.data then
        local d = reply.data
        local body = locale('notify.docked_charging', d.docked or '')
        if d.receipt then body = ('%s %s'):format(locale('notify.ride_ended', d.receipt.minutes, R.Currency, d.receipt.cost), body) end
        lib.notify({ title = locale('notify.title'), description = body, type = 'success' })
    else
        lib.notify({ title = locale('notify.title'), description = type(reply) == 'table' and reply.message or locale('ui.toast.failed'), type = 'error' })
    end
    docking = false
end

---Distance from the player's scooter to the closest dock of a station, measured at the slot the
---scooter would sit in rather than the station origin, so a long rail prompts only at the rail.
---@param point table
---@return number distance
local function dockDistance(point)
    if not point.entity or not DoesEntityExist(point.entity) or not cache.vehicle then return math.huge end
    local me = GetEntityCoords(cache.vehicle)
    local best = math.huge
    for slot = 1, dockCount(point.station) do
        local p = GetOffsetFromEntityInWorldCoords(point.entity, CFG.SlotX[slot], CFG.SlotY, 0.0)
        local d = #(me - p)
        if d < best then best = d end
    end
    return best
end

---Dock prompt logic for one point, run each frame while the player is near it.
---@param point table
---@param distance number metres from the station origin this frame
local function tickDock(point, distance)
    local riding = distance <= R.DockDistance and drivingScooter() and not docking
    if riding and dockDistance(point) <= DOCK.PromptDistance then
        showPrompt(point)
        if prompt and prompt.free > 0 and IsControlJustReleased(0, DOCK.Key) then dock() end
    elseif prompt and prompt.point == point then
        hidePrompt()
    end
end

---@type table Walk-up screen view tuning (configs/shared/stations.lua > Screen.View).
local VIEW = SCREEN.View
---@type table|false The station being viewed: { entity, station } while the scripted camera is up.
local viewing = false
---@type boolean True while an unlock request from the screen is in flight.
local unlocking = false
---@type integer[] Controls that close the screen view: 200/322 Escape, 202/194 Backspace (and Escape).
local CLOSE_CONTROLS = { 200, 322, 202, 194 }
---@type integer[] Held off while the view is up: pause menu (199 P, 200 Escape), 322 Escape, 202/194/177 frontend cancel.
local PAUSE_CONTROLS = { 199, 200, 322, 202, 194, 177 }

---Where the cursor sits on the screen glass, as page pixels, by projecting the glass corners to
---the viewport each frame and inverting that quad. nil when the cursor is off the glass.
---@param entity integer the station base prop
---@return number|nil px
---@return number|nil py
local function cursorOnScreen(entity)
    local sc, hw, hh = VIEW.ScreenCentre, VIEW.GlassSize.x / 2, VIEW.GlassSize.y / 2
    local corners = {}
    for i, off in ipairs({ vec2(-hw, hh), vec2(hw, hh), vec2(hw, -hh), vec2(-hw, -hh) }) do
        local w = GetOffsetFromEntityInWorldCoords(entity, sc.x + off.x, sc.y, sc.z + off.y)
        local ok, sx, sy = GetScreenCoordFromWorldCoord(w.x, w.y, w.z)
        if not ok then return nil end
        corners[i] = vec2(sx, sy)
    end
    local p = vec2(GetControlNormal(0, 239), GetControlNormal(0, 240))
    local a, b, c, d = corners[1], corners[2], corners[3], corners[4]
    local u, v = 0.5, 0.5
    for _ = 1, 6 do
        local e = a - b + c - d
        local s = a + (b - a) * u + (d - a) * v + e * (u * v) - p
        local du = (b - a) + e * v
        local dv = (d - a) + e * u
        local det = du.x * dv.y - du.y * dv.x
        if math.abs(det) < 1e-9 then return nil end
        u = u - (s.x * dv.y - s.y * dv.x) / det
        v = v - (du.x * s.y - du.y * s.x) / det
    end
    if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0 then return nil end
    return u * SCREEN.Width, v * SCREEN.Height
end

---Tell the page whether someone is at the glass, so it keeps the dock list up while they are.
---@param on boolean
local function setViewingFlag(on)
    if dui.ready then SendDuiMessage(dui.handle, json.encode({ viewing = on })) end
end

---Leave the screen view: camera eases back, the ped reappears.
---@param cam integer
local function leaveView(cam)
    setViewingFlag(false)
    SetEntityVisible(cache.ped, true, false)
    RenderScriptCams(false, true, VIEW.EaseMs, true, true)
    SetTimeout(VIEW.EaseMs + 50, function() DestroyCam(cam, false) end)
end

---Put a scripted camera in front of a station's screen until the player backs out. The mouse is
---drawn as a cursor and forwarded into the page so its buttons work like a touch screen.
---@param entity integer the station base prop
local function viewScreen(entity)
    if viewing or not entity or not DoesEntityExist(entity) then return end
    local station
    for _, point in pairs(points) do
        if point.entity == entity then station = point.station break end
    end
    if not station then return end
    viewing = { entity = entity, station = station }
    hidePrompt()
    local sc = VIEW.ScreenCentre
    local camPos = GetOffsetFromEntityInWorldCoords(entity, sc.x + VIEW.CameraOffset.x, sc.y + VIEW.CameraOffset.y, sc.z + VIEW.CameraOffset.z)
    local look = GetOffsetFromEntityInWorldCoords(entity, sc.x + VIEW.LookOffset.x, sc.y + VIEW.LookOffset.y, sc.z + VIEW.LookOffset.z)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamFov(cam, VIEW.Fov)
    RenderScriptCams(true, true, VIEW.EaseMs, true, true)
    SetEntityVisible(cache.ped, false, false)
    setViewingFlag(true)
    CreateThread(function()
        local pressed = false
        while viewing do
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            SetMouseCursorActiveThisFrame()
            SetMouseCursorSprite(VIEW.Cursor)
            if dui.ready and DoesEntityExist(entity) then
                local px, py = cursorOnScreen(entity)
                if px and py then
                    SendDuiMouseMove(dui.handle, math.floor(px), math.floor(py))
                    if IsDisabledControlJustPressed(0, 24) then
                        pressed = true
                        SendDuiMouseDown(dui.handle, 'left')
                    end
                end
                if pressed and IsDisabledControlJustReleased(0, 24) then
                    pressed = false
                    SendDuiMouseUp(dui.handle, 'left')
                end
            end
            for _, control in ipairs(PAUSE_CONTROLS) do DisableControlAction(0, control, true) end
            for _, control in ipairs(CLOSE_CONTROLS) do
                if IsDisabledControlJustPressed(0, control) then viewing = false end
            end
            Wait(0)
        end
        if pressed and dui.ready then SendDuiMouseUp(dui.handle, 'left') end
        leaveView(cam)
        local holdUntil = GetGameTimer() + 250
        while GetGameTimer() < holdUntil or IsDisabledControlPressed(0, 200) or IsDisabledControlPressed(0, 322) or IsDisabledControlPressed(0, 202) do
            for _, control in ipairs(PAUSE_CONTROLS) do DisableControlAction(0, control, true) end
            if GetGameTimer() > holdUntil + 2000 then break end
            Wait(0)
        end
    end)
end

---Tell the page how an unlock went; it shows the line under the docks.
---@param text string
---@param kind 'ok'|'error'
local function screenToast(text, kind)
    if dui.ready then SendDuiMessage(dui.handle, json.encode({ toast = { text = text, kind = kind } })) end
end

---The page's Unlock button: rent the scooter in that dock of the station being viewed. The server
---applies the app's distance, battery and fee rules; a success closes the view after a beat so
---the player sees the dock go free before stepping back.
RegisterNUICallback('scoot:screen:unlock', function(data, cb)
    cb(1)
    if not viewing or unlocking then return end
    local slot = tonumber(data and data.slot)
    if not slot then return end
    unlocking = true
    local stationId = viewing.station.id
    local reply = lib.callback.await('sd_scoot:server:stations:unlock', false, stationId, slot, type(data.account) == 'string' and data.account or nil)
    if type(reply) == 'table' and reply.success and reply.data and reply.data.ride then
        screenToast(locale('notify.ride_started', reply.data.ride.plate) or '', 'ok')
        lib.notify({ title = locale('notify.title'), description = locale('notify.ride_started', reply.data.ride.plate), type = 'success' })
        SetTimeout(VIEW.CloseAfterUnlockMs, function()
            if viewing and viewing.station.id == stationId then viewing = false end
        end)
    else
        local message = type(reply) == 'table' and reply.message or locale('ui.toast.failed')
        screenToast(message or '', 'error')
    end
    unlocking = false
end)

---Live settings changed (prices, charging rules): the screen gets them again.
AddEventHandler('sd_scoot:client:settingsApplied', function()
    if dui.handle then CreateThread(sendScreenConfig) end
end)

---The page has run its script: hand it the config and the current station state again.
RegisterNUICallback('scoot:screen:ready', function(_, cb)
    cb(1)
    if not dui.handle then return end
    sendScreenConfig()
    dui.last = nil
    refreshScreen()
    if viewing then setViewingFlag(true) end
end)

---The dock page's Stop charging button: end the running charge, refund what was not delivered.
RegisterNUICallback('scoot:screen:stopCharge', function(data, cb)
    cb(1)
    if not viewing or unlocking then return end
    local slot = tonumber(data and data.slot)
    if not slot then return end
    unlocking = true
    local reply = lib.callback.await('sd_scoot:server:stations:stopCharge', false, viewing.station.id, slot, type(data.account) == 'string' and data.account or nil)
    if type(reply) == 'table' and reply.success and reply.data then
        local r = reply.data
        local text = locale('notify.charge_stopped', r.plate, r.level) or ''
        if (r.refund or 0) > 0 then text = ('%s %s'):format(text, locale('notify.charge_refunded', R.Currency, r.refund) or '') end
        if dui.ready then SendDuiMessage(dui.handle, json.encode({ toast = { text = text, kind = 'ok' }, panel = 'close' })) end
        lib.notify({ title = locale('notify.title'), description = text, type = 'success' })
    else
        local message = type(reply) == 'table' and reply.message or locale('ui.toast.failed')
        screenToast(message or '', 'error')
    end
    unlocking = false
end)

---The page's confirm button on the charge panel: buy a charge to a target for the dock being
---viewed. The server prices it, takes the money and starts the charge; the page closes its panel
---on the ok toast.
RegisterNUICallback('scoot:screen:charge', function(data, cb)
    cb(1)
    if not viewing or unlocking then return end
    local slot, target = tonumber(data and data.slot), tonumber(data and data.target)
    if not slot or not target then return end
    unlocking = true
    local reply = lib.callback.await('sd_scoot:server:stations:charge', false, viewing.station.id, slot, target, type(data.account) == 'string' and data.account or nil)
    if type(reply) == 'table' and reply.success and reply.data then
        local q = reply.data
        local text = locale('notify.charge_bought', q.plate, q.target, R.Currency, q.cost, q.minutes) or ''
        if dui.ready then SendDuiMessage(dui.handle, json.encode({ toast = { text = text, kind = 'ok' }, panel = 'close' })) end
        lib.notify({ title = locale('notify.title'), description = text, type = 'success' })
    else
        local message = type(reply) == 'table' and reply.message or locale('ui.toast.failed')
        screenToast(message or '', 'error')
    end
    unlocking = false
end)

---@type boolean Whether ox_target took the screen option; otherwise a text prompt covers it.
local targeted = false

---Register the walk-up option on the station model with ox_target when it runs.
local function registerTarget()
    if targeted or GetResourceState('ox_target') ~= 'started' then return end
    exports.ox_target:addModel(joaat(CFG.Model), {
        {
            name = 'sd_scoot:viewScreen',
            icon = VIEW.Icon,
            label = VIEW.Label,
            distance = VIEW.Distance,
            onSelect = function(data) viewScreen(data.entity) end,
        },
    })
    targeted = true
end

---Text-prompt fallback for servers without ox_target: standing at the pillar on foot.
---@param point table
local function tickView(point)
    if targeted or viewing or cache.vehicle or not point.entity then return end
    local sc = VIEW.ScreenCentre
    local at = GetOffsetFromEntityInWorldCoords(point.entity, sc.x, sc.y - 0.6, 0.0)
    local near = #(GetEntityCoords(cache.ped) - at) <= VIEW.Distance
    if near then
        if not prompt or prompt.point ~= point or prompt.text ~= 'view' then
            prompt = { point = point, text = 'view', free = 0 }
            lib.showTextUI(locale('notify.view_screen'), { position = 'left-center', icon = 'charging-station' })
        end
        if IsControlJustReleased(0, DOCK.Key) then viewScreen(point.entity) end
    elseif prompt and prompt.point == point and prompt.text == 'view' then
        hidePrompt()
    end
end

---Register the lib.points entries for one published station: a wide one that only streams the
---props in and out, and a close one that carries the per-frame work (glow, dock prompt, screen
---prompt), so standing 200 m away costs nothing per frame.
---@param st table
local function addPoint(st)
    local coords = vec3(st.x, st.y, st.z)
    local point = lib.points.new({ coords = coords, distance = CFG.StreamDistance, station = st })
    function point:onEnter() spawnProps(self) end
    function point:onExit()
        if prompt and prompt.point == self then hidePrompt() end
        despawnProps(self)
    end
    local near = lib.points.new({ coords = coords, distance = GLOW_RANGE })
    function near:nearby()
        if not point.entity then return end
        drawGlow(point)
        tickDock(point, self.currentDistance)
        if self.currentDistance <= 6.0 then tickView(point) end
    end
    point.near = near
    points[st.id] = point
end

---Drop a station's points.
---@param point table
local function removePoint(point)
    if point.near then point.near:remove() end
    point:remove()
end

---Rebuild the point set from a published list: new stations get points, gone ones lose theirs,
---moved or re-slotted ones update in place.
---@param list table[]|nil
local function build(list)
    local seen = {}
    for _, st in ipairs(list or {}) do
        seen[st.id] = true
        local point = points[st.id]
        if point then
            local moved = point.station.x ~= st.x or point.station.y ~= st.y or point.station.z ~= st.z or point.station.heading ~= st.heading
                or dockCount(point.station) ~= dockCount(st) or stationColour(point.station) ~= stationColour(st)
            point.station = st
            if moved then
                despawnProps(point)
                removePoint(point)
                addPoint(st)
            else
                applySlots(point)
            end
        else
            addPoint(st)
        end
    end
    for id, point in pairs(points) do
        if not seen[id] then
            if prompt and prompt.point == point then hidePrompt() end
            despawnProps(point)
            removePoint(point)
            points[id] = nil
        end
    end
    refreshScreen()
end

---Rebuild the local stations whenever the server publishes a new list.
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    build(value)
end)

---@type table<integer, table> Per-vehicle glide state: entity -> { token, station, slot }.
local glides = {}

---Forward unit vector of a heading, in the world XY plane.
---@param heading number degrees
---@return vector3
local function forward(heading)
    local r = math.rad(heading)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

---Shortest signed difference between two headings.
---@param from number
---@param to number
---@return number
local function headingDelta(from, to)
    return (to - from + 540.0) % 360.0 - 180.0
end

---Move a frozen vehicle from where it is to a pose over ms, easing both position and heading.
---Returns false when the glide was superseded by a newer state.
---@param veh integer
---@param token integer
---@param to vector3
---@param heading number
---@param ms number
---@return boolean finished
local function glideTo(veh, token, to, heading, ms)
    local from = GetEntityCoords(veh)
    local h0 = GetEntityHeading(veh)
    local dh = headingDelta(h0, heading)
    local start = GetGameTimer()
    while true do
        local t = (GetGameTimer() - start) / ms
        if not DoesEntityExist(veh) or glides[veh] == nil or glides[veh].token ~= token then return false end
        local k = ease(t)
        local p = from + (to - from) * k
        SetEntityCoordsNoOffset(veh, p.x, p.y, p.z, false, false, false)
        SetEntityRotation(veh, 0.0, 0.0, (h0 + dh * k) % 360.0, 2, true)
        if t >= 1.0 then return true end
        Wait(0)
    end
end

---Try to own a vehicle for a moment so this client can drive its glide.
---@param veh integer
---@return boolean
local function takeControl(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    NetworkRequestControlOfEntity(veh)
    local waited = 0
    while not NetworkHasControlOfEntity(veh) and waited < 600 do
        Wait(50)
        waited = waited + 50
    end
    return NetworkHasControlOfEntity(veh)
end

---The dock a state bag refers to, if its station is streamed here.
---@param value table
---@return table|nil point
local function dockPoint(value)
    local point = value.station and points[value.station]
    if point and point.entity and DoesEntityExist(point.entity) then return point end
    return nil
end

---A docked scooter is pinned on its slot pose by whichever client streams it, so physics, the
---rider stepping off or a passing car cannot nudge it out of the dock. The server narrates the
---dock as phases: `in` (bars up, glide in, bars down), `docked` (sit still), `out` (bars up, glide
---out) and then false (free). The owning client moves the vehicle; everyone animates the bars.
---@type table<integer, table> Stem clamps by vehicle: { clamp, jaw, bone, token } entities a docked scooter wears.
local plugs = {}
---@type table Clamp timeline (configs/shared/stations.lua > PlugAnim).
local PA = CFG.PlugAnim

---Set a docked scooter's pose and hold it there. A frozen entity ignores a new rotation, so it is
---released for the moment the pose is applied.
---@param veh integer
---@param pose table { x, y, z, heading }
local function pinDocked(veh, pose)
    FreezeEntityPosition(veh, false)
    SetEntityCoordsNoOffset(veh, pose.x + 0.0, pose.y + 0.0, pose.z + 0.0, false, false, false)
    SetEntityRotation(veh, 0.0, 0.0, pose.heading + 0.0, 2, true)
    FreezeEntityPosition(veh, true)
end

---A collision-free clamp part at the scooter's position, or nil when its model is not configured.
---@param name string|nil
---@param veh integer
---@return integer|nil
local function clampPart(name, veh)
    local hash = name and model(name)
    if not hash then return nil end
    local at = GetEntityCoords(veh)
    local obj = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    return obj
end

---Pose both clamp halves: `slide` metres along the bone's X (negative tucks them into the puck),
---the jaw `angle` degrees open about the stem axis and faded to `alpha` (0..255).
---@param veh integer
---@param p table plugs entry
---@param slide number
---@param angle number
---@param alpha integer
local function posePlug(veh, p, slide, angle, alpha)
    local o, h = CFG.PlugOffset, CFG.JawHinge
    if p.clamp and DoesEntityExist(p.clamp) then
        AttachEntityToEntity(p.clamp, veh, p.bone, o.x + slide, o.y, o.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    end
    if p.jaw and DoesEntityExist(p.jaw) then
        AttachEntityToEntity(p.jaw, veh, p.bone, h.x + slide, h.y, h.z, 0.0, 0.0, angle, false, false, false, false, 2, true)
        if alpha >= 255 then ResetEntityAlpha(p.jaw) else SetEntityAlpha(p.jaw, alpha, false) end
        SetEntityVisible(p.jaw, alpha > 0, false)
    end
end

---Ease-out with a small overshoot, so the jaw snaps a few degrees past closed and settles back.
---@param t number 0..1
---@return number
local function easeOutBack(t)
    t = math.max(0.0, math.min(1.0, t)) - 1.0
    local s = 1.2
    return t * t * ((s + 1.0) * t + s) + 1.0
end

---Run a clamp timeline frame by frame until `step` reports done or the clamp is replaced.
---@param veh integer
---@param p table
---@param step fun(ms: integer): boolean
local function playPlug(veh, p, step)
    local start = GetGameTimer()
    while plugs[veh] == p and DoesEntityExist(veh) do
        if step(GetGameTimer() - start) then return end
        Wait(0)
    end
end

---Clamp a docked scooter's stem. Animated: the dock-side half slides out of the puck onto the
---stem, then the jaw fades in and swings shut around it. Otherwise it appears closed, for scooters
---that stream in already docked. Idempotent; blocks for the animation when `animate` is set.
---@param veh integer
---@param animate boolean|nil
local function attachPlug(veh, animate)
    if not CFG.PlugModel or plugs[veh] then return end
    local bone = GetEntityBoneIndexByName(veh, CFG.PlugBone or 'chassis')
    if bone < 0 then return end
    local p = { bone = bone, clamp = clampPart(CFG.PlugModel, veh), jaw = clampPart(CFG.JawModel, veh) }
    if not p.clamp then
        if p.jaw then DeleteEntity(p.jaw) end
        return
    end
    plugs[veh] = p
    if not animate then
        posePlug(veh, p, 0.0, 0.0, 255)
        return
    end
    posePlug(veh, p, -PA.Slide, PA.JawOpen, 0)
    playPlug(veh, p, function(ms)
        if ms < PA.SlideMs then
            posePlug(veh, p, -PA.Slide * (1.0 - ease(ms / PA.SlideMs)), PA.JawOpen, 0)
            return false
        end
        local swing = (ms - PA.SlideMs) / PA.SwingMs
        local alpha = math.floor(255 * math.min(1.0, (ms - PA.SlideMs) / PA.FadeMs))
        posePlug(veh, p, 0.0, PA.JawOpen * (1.0 - easeOutBack(swing)), alpha)
        return swing >= 1.0
    end)
    if plugs[veh] == p then posePlug(veh, p, 0.0, 0.0, 255) end
end

---Take the clamp off at once. Idempotent.
---@param veh integer
local function dropPlug(veh)
    local p = plugs[veh]
    plugs[veh] = nil
    if not p then return end
    for _, ent in ipairs({ p.clamp, p.jaw }) do
        if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end

---Unclamp before the scooter backs out: the jaw swings open and fades, then the dock-side half
---tucks back into the puck. Blocks for the animation, then removes both halves.
---@param veh integer
local function releasePlug(veh)
    local p = plugs[veh]
    if not p then return end
    playPlug(veh, p, function(ms)
        if ms < PA.ReleaseMs then
            local left = PA.ReleaseMs - ms
            posePlug(veh, p, 0.0, PA.JawOpen * ease(ms / PA.ReleaseMs), math.floor(255 * math.min(1.0, left / PA.FadeMs)))
            return false
        end
        local t = (ms - PA.ReleaseMs) / PA.SlideMs
        posePlug(veh, p, -PA.Slide * ease(t), PA.JawOpen, 0)
        return t >= 1.0
    end)
    if plugs[veh] == p then dropPlug(veh) end
end

---Docked scooters that streamed in, or were parked before this script loaded, never saw a state bag
---change, so their pose is checked here and set straight again when it has drifted.
---Checked twice a second and on small tilts too: a bike left to its own physics settles onto a
---parked lean within a second, and a docked scooter should never be seen doing that.
CreateThread(function()
    while true do
        Wait(fleet.any() and 500 or 1000)
        local streamed = false
        for _, point in pairs(points) do
            if point.entity then streamed = true break end
        end
        for _, veh in ipairs(streamed and fleet.list() or {}) do
            if GetEntityModel(veh) == SCOOTER and GetPedInVehicleSeat(veh, -1) == 0 then
                local pose = Entity(veh).state['sd_scoot_dock']
                if type(pose) == 'table' and pose.phase == 'docked' and pose.heading then
                    local off = math.abs(headingDelta(GetEntityHeading(veh), pose.heading))
                    local drift = #(GetEntityCoords(veh) - vector3(pose.x, pose.y, pose.z))
                    local tilt = math.max(math.abs(GetEntityRoll(veh)), math.abs(GetEntityPitch(veh)))
                    if off > 1.0 or drift > 0.05 or tilt > 0.5 then
                        if NetworkHasControlOfEntity(veh) or takeControl(veh) then
                            log.debug('stations', 'docked scooter %d re-pinned (tilt %.1f, turn %.1f, drift %.2f)', veh, tilt, off, drift)
                            pinDocked(veh, pose)
                        end
                    end
                    attachPlug(veh)
                end
            end
        end
    end
end)

---Dock state for a scooter changed. Nil releases it (plug dropped, entity unfrozen, hoop reset);
---phase 'in' glides it into the slot and plugs it in, 'out' unplugs and glides it clear, and
---'docked' pins it at the slot pose. A token per vehicle aborts a glide superseded by a newer state.
AddStateBagChangeHandler('sd_scoot_dock', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if not veh or veh == 0 then return end
    local tries = 0
    while not DoesEntityExist(veh) and tries < 50 do
        Wait(100)
        tries = tries + 1
    end
    if not DoesEntityExist(veh) then return end
    local token = (glides[veh] and glides[veh].token or 0) + 1
    if type(value) ~= 'table' then
        local last = glides[veh]
        glides[veh] = nil
        dropPlug(veh)
        FreezeEntityPosition(veh, false)
        if last and last.station then
            local point = points[last.station]
            if point then setHoop(point, last.slot, true) end
        end
        return
    end
    glides[veh] = { token = token, station = value.station, slot = value.slot }
    local pose = vector3(value.x, value.y, value.z)
    local point = dockPoint(value)
    local phase = value.phase or 'docked'
    if phase == 'in' then
        if point then setHoop(point, value.slot, true) end
        if takeControl(veh) then
            FreezeEntityPosition(veh, true)
            Wait(150)
            local fwd = forward(value.heading)
            local here = GetEntityCoords(veh)
            local toPose = pose - here
            local depth = toPose.x * fwd.x + toPose.y * fwd.y
            depth = math.max(ANIM.MinApproach, math.min(ANIM.ApproachDistance, depth))
            local lineUp = pose - fwd * depth
            local lateral = #(here - lineUp)
            local turn = math.abs(headingDelta(GetEntityHeading(veh), value.heading))
            local approachMs = ANIM.Approach * math.max(0.2, math.min(1.3, lateral / 1.0 + turn / 90.0))
            local slideMs = ANIM.Slide * math.max(0.4, math.min(1.0, depth / ANIM.ApproachDistance))
            if glideTo(veh, token, lineUp, value.heading, approachMs) and glideTo(veh, token, pose, value.heading, slideMs) then
                FreezeEntityPosition(veh, false)
                SetEntityRotation(veh, 0.0, 0.0, value.heading, 2, true)
                FreezeEntityPosition(veh, true)
            end
        else
            Wait(150 + ANIM.Approach + ANIM.Slide)
            if glides[veh] and glides[veh].token == token then
                FreezeEntityPosition(veh, false)
                SetEntityRotation(veh, 0.0, 0.0, value.heading, 2, true)
                FreezeEntityPosition(veh, true)
            end
        end
        Wait(ANIM.Settle)
        local now = glides[veh]
        if now and now.station == value.station and now.slot == value.slot then
            if point then setHoop(point, value.slot, false) end
            attachPlug(veh, true)
        end
    elseif phase == 'out' then
        if point then setHoop(point, value.slot, true) end
        releasePlug(veh)
        if glides[veh] == nil or glides[veh].token ~= token then return end
        if takeControl(veh) then
            FreezeEntityPosition(veh, true)
            local exit = pose - forward(value.heading) * ANIM.ExitDistance
            if glideTo(veh, token, exit, value.heading, ANIM.Out) then SetVehicleOnGroundProperly(veh) end
        end
    else
        local function pin()
            pinDocked(veh, { x = pose.x, y = pose.y, z = pose.z, heading = value.heading })
        end
        pin()
        if point then setHoop(point, value.slot, false) end
        attachPlug(veh)
        Wait(250)
        if glides[veh] and glides[veh].token == token then pin() end
    end
end)

---Server push: the scooter under this player is about to be parked in a dock; step off first.
RegisterNetEvent('sd_scoot:client:leaveVehicle', function()
    if cache.vehicle then TaskLeaveVehicle(cache.ped, cache.vehicle, 0) end
end)

---/scootflush: despawn every station prop, release all station models, then respawn the props of
---stations still in stream range so changed assets are picked up.
RegisterNetEvent('sd_scoot:client:flush', function()
    for _, point in pairs(points) do despawnProps(point) end
    local names = {}
    for _, name in pairs({ CFG.Model, CFG.EndModel, CFG.LightsModel, CFG.HoopModel, CFG.PlugModel, CFG.JawModel, CFG.LensModels.idle, CFG.LensModels.charging, CFG.LensModels.full }) do names[#names + 1] = name end
    for _, name in pairs(type(CFG.DockModel) == 'table' and CFG.DockModel or { CFG.DockModel }) do names[#names + 1] = name end
    for _, point in pairs(points) do
        local colour = stationColour(point.station)
        if CFG.ShellModel then names[#names + 1] = CFG.ShellModel:format(colour) end
        if CFG.TotemShellModel then names[#names + 1] = CFG.TotemShellModel:format(colour) end
    end
    for _, name in ipairs(names) do SetModelAsNoLongerNeeded(joaat(name)) end
    Wait(500)
    for _, point in pairs(points) do
        if point.currentDistance and point.currentDistance <= CFG.StreamDistance then spawnProps(point) end
    end
end)

---ox_target started after this resource: register the pillar screen target with it.
AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_target' then registerTarget() end
end)

---Build the published stations and register the target, then refresh the pillar screens on a timer.
CreateThread(function()
    Wait(1000)
    build(GlobalState[STATE_KEY])
    registerTarget()
    while true do
        Wait(SCREEN.RefreshMs)
        refreshScreen()
    end
end)

---Clean up on stop: hide the prompt, drop plugs, leave the screen camera, remove the target, destroy
---the DUI and despawn every station prop.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hidePrompt()
    for veh in pairs(plugs) do dropPlug(veh) end
    if viewing then
        viewing = false
        SetEntityVisible(cache.ped, true, false)
        RenderScriptCams(false, false, 0, true, true)
    end
    if targeted and GetResourceState('ox_target') == 'started' then pcall(function() exports.ox_target:removeModel(joaat(CFG.Model), 'sd_scoot:viewScreen') end) end
    destroyDui()
    for _, point in pairs(points) do despawnProps(point) end
end)

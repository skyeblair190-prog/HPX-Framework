---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Ghost placement tool (client/scoot/placer.lua).
local placer = require 'client.scoot.placer'
---@type table Live handling: preview, test ride, published values (client/scoot/handling.lua).
local handlingLive = require 'client.scoot.handling'

---@type table Charging station config (configs/shared/stations.lua).
local ST = config.Stations
---@type string GlobalState key the server publishes enabled stations under.
local STATIONS_KEY = 'sd_scoot:stations'

---@type boolean Whether the panel is open. Hidden-for-placement still counts as open: focus comes
---back the moment the placer returns.
local open = false

---Ask the server. Every panel action is one lib.callback under sd_scoot:server:admin:<verb>, and
---every reply has the same shape, so a lost reply is turned into a failure here rather than nil.
---@param verb string
---@param data table|nil
---@return table reply { success: boolean, message?: string, data?: table }
local function request(verb, data)
    local reply = lib.callback.await('sd_scoot:server:admin:' .. verb, false, data or {})
    if type(reply) ~= 'table' then return { success = false, message = locale('ui.toast.failed') } end
    return reply
end

---Other resources (and the dev probes) can drive the panel's server side without the NUI.
exports('adminRequest', request)

---Send one message to the admin panel NUI.
---@param action string NUI action (scoot:admin:<verb>)
---@param data table|nil
local function push(action, data)
    SendNUIMessage({ action = action, data = data })
end

---The placement gizmo draws its HUD in this page while the panel is hidden.
placer.setHud(function(action, data) push(action, data) end)

---Take focus and mount the panel with a fresh snapshot.
---@param snap table
local function show(snap)
    SetNuiFocus(true, true)
    push('scoot:admin:open', { snapshot = snap })
end

---Drop focus and hide the panel (it stays mounted) so the admin can aim the placer.
local function hideForPlacement()
    push('scoot:admin:hide')
    SetNuiFocus(false, false)
end

---Bring the panel back after a placement with the outcome and a fresh snapshot.
---@param placed table { kind, success, message?, cancelled? }
local function showAfterPlacement(placed)
    local snap = request('snapshot')
    SetNuiFocus(true, true)
    push('scoot:admin:show', { snapshot = snap.data, placed = placed })
end

---Close for good. Idempotent. Drops any handling draft and the test scooter with it.
local function close()
    open = false
    handlingLive.reset()
    SetNuiFocus(false, false)
    push('scoot:admin:close')
end

---Server push: open the admin panel. Fetches a snapshot first and shows the error instead when
---the server refuses it; ignored while the panel is already open.
RegisterNetEvent('sd_scoot:client:openAdmin', function()
    if open then return end
    local snap = request('snapshot')
    if not snap.success then
        lib.notify({ title = locale('notify.title'), description = snap.message, type = 'error' })
        return
    end
    open = true
    show(snap.data)
end)

---NUI callback: the panel asked to close (Escape or the X).
RegisterNUICallback('scoot:admin:close', function(_, cb)
    cb({ ok = true })
    close()
end)

---@type table<string, string> Plain pass-throughs: NUI verb -> server verb. The reply goes straight
---back to the panel, which re-renders from the snapshot inside it.
local PASS = {
    snapshot = 'snapshot',
    renamebunker = 'renameBunker',
    togglebunker = 'toggleBunker',
    deletebunker = 'deleteBunker',
    deleteallbunkers = 'deleteAllBunkers',
    deleteallstations = 'deleteAllStations',
    renamestation = 'renameStation',
    togglestation = 'toggleStation',
    deletestation = 'deleteStation',
    setstationslots = 'setStationSlots',
    setstationcolour = 'setStationColour',
    spawnatbunker = 'spawnAtBunker',
    deletescooter = 'deleteScooter',
    respawnscooter = 'respawnScooter',
    setscootercolour = 'setScooterColour',
    positions = 'positions',
    handling = 'handling',
    handlingcreate = 'handlingCreate',
    handlingactivate = 'handlingActivate',
    handlingrename = 'handlingRename',
    handlingdelete = 'handlingDelete',
    handlingundo = 'handlingUndo',
    setbunkerstock = 'setBunkerStock',
    releasedock = 'releaseDock',
    undodelete = 'undoDelete',
    setscooterbattery = 'setScooterBattery',
    lockscooter = 'lockScooter',
    bringscooter = 'bringScooter',
    sendhome = 'sendHome',
    bulkscooters = 'bulkScooters',
    mapactivity = 'mapActivity',
    rides = 'rides',
    ridehistory = 'rideHistory',
    playerrides = 'playerRides',
    forceendride = 'forceEndRide',
    refundride = 'refundRide',
    auditlog = 'auditLog',
    settings = 'settings',
    settingssave = 'settingsSave',
    settingsreset = 'settingsReset',
    handlingexport = 'handlingExport',
}

---Register one NUI callback per pass-through verb, each relaying straight to the server.
for nuiVerb, serverVerb in pairs(PASS) do
    RegisterNUICallback('scoot:admin:' .. nuiVerb, function(data, cb)
        cb(request(serverVerb, data))
    end)
end

---Run the placer with the panel hidden, create (or move) the record from the result, and bring
---the panel back with the outcome. `build` turns the placed transform into the server verb +
---payload; the toast key names both the noun and what happened (notify.<what>_placed|_moved).
---@param kind string 'object' | 'vehicle'
---@param modelName string
---@param labelKey string locale key for the text UI noun
---@param placedKey string locale key for the success toast, given the record's name
---@param build fun(spot: table): string, table
---@param parts table[]|nil extra props previewed alongside the root model
---@param from table|nil where the thing stands now, when moving it
---@param opts table|nil placer options (HUD warnings)
local function placeAndCreate(kind, modelName, labelKey, placedKey, build, parts, from, opts)
    hideForPlacement()
    local spot, err = placer.start(kind, modelName, locale(labelKey), parts, from, opts)
    local placed
    if spot then
        local reply = request(build(spot))
        local what, action = placedKey:match('notify%.(%a+)_(%a+)')
        placed = { kind = kind, what = what, action = action, success = reply.success, message = reply.message }
        if reply.success then
            local d = reply.data or {}
            local name = (d.bunker and d.bunker.name) or (d.station and d.station.name) or (d.scooter and d.scooter.plate) or ''
            lib.notify({ title = locale('notify.title'), description = locale(placedKey, name), type = 'success' })
        end
    else
        placed = { kind = kind, success = false, cancelled = err == nil, message = locale(err or 'err.placement_cancelled') }
    end
    log.debug('admin', 'placement %s: %s', kind, placed.success and 'ok' or placed.message)
    if open then showAfterPlacement(placed) end
end

---Clamp a panel-supplied integer into range, falling back when it is missing or nonsense.
---@param n any
---@param lo integer
---@param hi integer
---@param fallback integer
---@return integer
local function clamped(n, lo, hi, fallback)
    n = math.tointeger(tonumber(n) or 0) or 0
    if n < lo or n > hi then return fallback end
    return n
end

---Find a published station by id so moving one previews the station it actually is.
---@param id any
---@return table|nil
local function publishedStation(id)
    for _, st in ipairs(GlobalState[STATIONS_KEY] or {}) do
        if st.id == id then return st end
    end
    return nil
end

---The ghost's extra parts for a station: the painted totem shell, a dock module and its post
---shell per slot, then the rounded end cap. Mirrors what a station's points spawn, so what is
---previewed is what gets built.
---@param count integer dock count
---@param colour integer palette index
---@return table[]
local function stationParts(count, colour)
    local list = {}
    local function add(model, x)
        if model then list[#list + 1] = { model = model, offset = vec3(x, 0.0, 0.0) } end
    end
    add(ST.TotemShellModel and ST.TotemShellModel:format(colour), 0.0)
    for slot = 1, count do
        add(type(ST.DockModel) == 'table' and ST.DockModel[slot] or ST.DockModel, ST.SlotX[slot])
        add(ST.ShellModel and ST.ShellModel:format(colour), ST.SlotX[slot])
    end
    add(ST.EndModel, ST.RailStart + ST.DockPitch * count)
    return list
end

---NUI callback: place a bunker. Replies immediately; the panel waits for scoot:admin:show.
RegisterNUICallback('scoot:admin:placebunker', function(data, cb)
    cb({ ok = true })
    placeAndCreate('object', config.Bunkers.Model, 'placer.bunker', 'notify.bunker_placed', function(spot)
        return 'createBunker', { name = data.name, x = spot.x, y = spot.y, z = spot.z, heading = spot.heading }
    end)
end)

---NUI callback: place a charging station. Replies immediately; the panel waits for scoot:admin:show.
RegisterNUICallback('scoot:admin:placestation', function(data, cb)
    cb({ ok = true })
    local count = clamped(data.count, 1, ST.MaxSlots, ST.MaxSlots)
    local colour = clamped(data.colour, 1, #ST.Colours, ST.DefaultColour or 1)
    placeAndCreate('object', ST.Model, 'placer.station', 'notify.station_placed', function(spot)
        return 'createStation', { name = data.name, x = spot.x, y = spot.y, z = spot.z, heading = spot.heading, count = count, colour = colour }
    end, stationParts(count, colour))
end)

---A published bunker by id, so a move starts the ghost where the bunker stands.
---@param id any
---@return table|nil
local function publishedBunker(id)
    for _, b in ipairs(GlobalState['sd_scoot:bunkers'] or {}) do
        if b.id == id then return b end
    end
    return nil
end

---NUI callback: pick a new spot for an existing bunker. Same placer, the record keeps its id.
RegisterNUICallback('scoot:admin:movebunker', function(data, cb)
    cb({ ok = true })
    local b = publishedBunker(data.id)
    placeAndCreate('object', config.Bunkers.Model, 'placer.bunker', 'notify.bunker_moved', function(spot)
        return 'moveBunker', { id = data.id, x = spot.x, y = spot.y, z = spot.z, heading = spot.heading }
    end, nil, b and { x = b.x, y = b.y, z = b.z, heading = b.heading } or nil)
end)

---NUI callback: pick a new spot for an existing station; whatever is docked in it comes along.
RegisterNUICallback('scoot:admin:movestation', function(data, cb)
    cb({ ok = true })
    local st = publishedStation(data.id)
    local count = clamped(st and st.count, 1, ST.MaxSlots, ST.MaxSlots)
    local colour = clamped(st and st.colour, 1, #ST.Colours, ST.DefaultColour or 1)
    placeAndCreate('object', ST.Model, 'placer.station', 'notify.station_moved', function(spot)
        return 'moveStation', { id = data.id, x = spot.x, y = spot.y, z = spot.z, heading = spot.heading }
    end, stationParts(count, colour), st and { x = st.x, y = st.y, z = st.z, heading = st.heading } or nil)
end)

---NUI callback: spawn a scooter on the admin (colour + optional home bunker), put them on it with the
---keys, and close the panel so they can ride straight off.
RegisterNUICallback('scoot:admin:spawnscooteronme', function(data, cb)
    local reply = request('spawnScooterOnMe', data)
    cb(reply)
    if not reply.success or not reply.data or not reply.data.netId then return end
    local netId = reply.data.netId
    close()
    CreateThread(function()
        local deadline = GetGameTimer() + 5000
        while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < deadline do Wait(50) end
        if not NetworkDoesEntityExistWithNetworkId(netId) then return end
        local veh = NetToVeh(netId)
        for _ = 1, 20 do
            TaskWarpPedIntoVehicle(cache.ped, veh, -1)
            Wait(100)
            if GetVehiclePedIsIn(cache.ped, false) == veh then break end
        end
        lib.notify({ title = locale('notify.title'), description = locale('notify.scooter_placed', reply.data.scooter and reply.data.scooter.plate or ''), type = 'success' })
    end)
end)

---NUI callback: teleport next to a bunker or scooter. The server resolves the target so a stale
---row in the panel cannot send the admin somewhere the thing no longer is.
RegisterNUICallback('scoot:admin:teleport', function(data, cb)
    local reply = request('teleport', data)
    if reply.success and reply.data then
        local d = reply.data
        local ent = cache.vehicle or cache.ped
        SetEntityCoords(ent, d.x + 1.5, d.y + 1.5, d.z + 1.0, false, false, false, false)
        lib.notify({ title = locale('notify.title'), description = locale('notify.teleported'), type = 'inform' })
    end
    cb(reply)
end)

---NUI callback: save a handling profile. A save of the profile being previewed means the draft is
---now what everyone gets, so the local preview is dropped in favour of the published values.
RegisterNUICallback('scoot:admin:handlingsave', function(data, cb)
    local reply = request('handlingSave', data)
    if reply.success then handlingLive.clearPreview() end
    cb(reply)
end)

---NUI callback: show the unsaved draft on the admin's own scooter while they tune.
RegisterNUICallback('scoot:admin:handlingpreview', function(data, cb)
    cb({ success = true, data = { onScooter = handlingLive.setPreview(data.values) } })
end)

---NUI callback: throw the draft away; the admin's scooter returns to the published values.
RegisterNUICallback('scoot:admin:handlingdiscard', function(_, cb)
    handlingLive.clearPreview()
    cb({ success = true })
end)

---NUI callback: play a horn from the handling editor on the admin's scooter or the nearest one.
RegisterNUICallback('scoot:admin:hornpreview', function(data, cb)
    local played = type(data) == 'table' and type(data.horn) == 'string' and handlingLive.previewHorn(data.horn)
    cb(played and { success = true } or { success = false, message = locale('ui.handling.horn_no_scooter') })
end)

---NUI callback: hide the panel and ride the draft; the return key brings the panel back.
RegisterNUICallback('scoot:admin:handlingtest', function(data, cb)
    local started, err = handlingLive.startTest(data.values or {}, push)
    if not started then
        cb({ success = false, message = locale(err or 'ui.toast.failed') })
        return
    end
    cb({ success = true })
    hideForPlacement()
end)

---Return key during a test ride: stop the readout and give the panel focus back.
lib.addKeybind({
    name = 'sd_scoot_handling_return',
    description = 'SCOOT handling editor: return to the panel from a test ride',
    defaultKey = config.Handling.ReturnKey or 'F7',
    onPressed = function()
        if not open or not handlingLive.isTesting() then return end
        handlingLive.stopTest()
        push('scoot:handling:test', { active = false })
        SetNuiFocus(true, true)
        push('scoot:admin:show', {})
    end,
})

---NUI callback: teleport to a point clicked on the map. The server authorises it; the ground height
---is only known here, once the collision around the point has loaded.
RegisterNUICallback('scoot:admin:teleportpoint', function(data, cb)
    local reply = request('teleportPoint', data)
    cb(reply)
    if not reply.success or not reply.data then return end
    local x, y = reply.data.x + 0.0, reply.data.y + 0.0
    local ent = cache.vehicle or cache.ped
    CreateThread(function()
        FreezeEntityPosition(ent, true)
        local z, found = 1000.0, false
        for _ = 1, 40 do
            RequestCollisionAtCoord(x, y, z)
            SetEntityCoordsNoOffset(ent, x, y, z, false, false, false)
            Wait(50)
            local hit, ground = GetGroundZFor_3dCoord(x, y, 1000.0, false)
            if hit then
                z, found = ground + 1.0, true
                break
            end
        end
        SetEntityCoordsNoOffset(ent, x, y, found and z or 100.0, false, false, false)
        FreezeEntityPosition(ent, false)
        lib.notify({ title = locale('notify.title'), description = locale('notify.teleported'), type = 'inform' })
    end)
end)

---Ground height under a set of points, for server-side placement helpers that only know x and y.
---The server's own coordinates come from a ped, whose origin sits a metre above its feet, so
---anything placed from them would hang in the air.
---@param points table[] each { x, y, z }
---@return number[] one ground z per point; the point's own z when the probe finds nothing
lib.callback.register('sd_scoot:client:groundZ', function(points)
    local out = {}
    for i, p in ipairs(points or {}) do
        local found, z = GetGroundZFor_3dCoord(p.x + 0.0, p.y + 0.0, (p.z or 0.0) + 2.0, false)
        out[i] = found and z or p.z
    end
    return out
end)

---Cancel any running placement and release NUI focus when this resource stops.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if placer.isActive() then placer.cancel() end
    SetNuiFocus(false, false)
end)

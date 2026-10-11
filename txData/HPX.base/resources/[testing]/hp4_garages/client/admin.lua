local visible, markersOn = false, false
local snapshot

local function call(action, data)
    return lib.callback.await('hp4_garages:admin', false, action, data or {})
end

local function setFocus(state)
    visible = state
    SetNuiFocus(state, state)
end

local function open()
    local res = call('snapshot')
    if not res or not res.ok then return end
    snapshot = res.snapshot
    markersOn = true
    setFocus(true)
    SendNUIMessage({ action = 'open', data = snapshot })
end

local function close()
    markersOn = false
    if visible then setFocus(false) end
    SendNUIMessage({ action = 'close' })
end

local function toggle()
    if visible then close() else open() end
end

RegisterCommand(Config.command, toggle, false)
lib.addKeybind({ name = 'hp4_garage_admin', description = 'Garage admin panel', defaultKey = 'F7', onPressed = toggle })

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('hide', function(_, cb)
    if visible then setFocus(false) end
    SendNUIMessage({ action = 'hidden' })
    cb('ok')
end)

RegisterNUICallback('call', function(body, cb)
    local action, data = body and body.action, body and body.data or {}
    if type(action) ~= 'string' then return cb({ ok = false, err = 'unknown' }) end

    if action == 'vehicle:persist' then
        local veh = cache.vehicle
        if not veh then return cb({ ok = false, err = 'not_in_vehicle' }) end
        data.netId = NetworkGetNetworkIdFromEntity(veh)
        data.label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
        data.props = lib.getVehicleProperties(veh)
    end

    local res = call(action, data)
    if res and res.snapshot then snapshot = res.snapshot end
    cb(res or { ok = false, err = 'error' })
end)

CreateThread(function()
    while true do
        local wait = 500
        if markersOn and snapshot then
            local pc = GetEntityCoords(cache.ped)
            for _, g in ipairs(snapshot.garages) do
                for _, s in ipairs(g.spots) do
                    if #(vector3(s.x, s.y, s.z) - pc) < Config.markerDistance then
                        wait = 0
                        local r, gr, b = 62, 207, 115
                        if s.state == 'occupied' then r, gr, b = 239, 91, 91
                        elseif s.state ~= 'free' then r, gr, b = 229, 163, 59 end
                        DrawMarker(25, s.x, s.y, s.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 1.0, r, gr, b, 150, false, false, 2, false, nil, nil, false)
                        local rad = math.rad(s.h + 90.0)
                        DrawLine(s.x, s.y, s.z + 0.3, s.x + math.cos(rad) * 2.5, s.y + math.sin(rad) * 2.5, s.z + 0.3, r, gr, b, 255)
                    end
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if visible then SetNuiFocus(false, false) end
end)

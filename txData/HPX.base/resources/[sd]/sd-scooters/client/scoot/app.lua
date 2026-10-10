---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'

---@type table Rental tuning + app manifest (configs/shared/rentals.lua).
local CFG = config.Rentals
---@type string This resource's name, so the manifest works unchanged in the dev twin.
local RESOURCE = cache.resource or GetCurrentResourceName()

---Ask the server. Every app action is one lib.callback under sd_scoot:server:app:<verb>.
---@param verb string
---@param data table|nil
---@return table reply { success, message?, data? }
local function request(verb, data)
    local reply = lib.callback.await('sd_scoot:server:app:' .. verb, false, data or {})
    if type(reply) ~= 'table' then return { success = false, message = locale('ui.toast.failed') } end
    return reply
end

---The lb-phone shaped manifest both phones accept. `ui` is our own NUI page, which the phone
---loads in an iframe; `icon` is an image URL served from the same build.
---@return table
local function manifest()
    local app = CFG.App
    return {
        identifier = app.identifier,
        name = app.name,
        description = app.description,
        developer = app.developer,
        defaultApp = app.defaultApp,
        size = app.size,
        wifi = app.wifi,
        ui = ('%s/web/build/app/index.html'):format(RESOURCE),
        icon = ('https://cfx-nui-%s/web/build/app/icon.svg'):format(RESOURCE),
        images = { ('https://cfx-nui-%s/web/build/app/icon.svg'):format(RESOURCE) },
    }
end

---True when the started lb-phone is sd-phone's own compatibility shim, in which case registering
---through both names would create the app twice.
---@return boolean
local function lbIsShim()
    return GetResourceMetadata('lb-phone', 'sd_phone_shim', 0) == 'yes'
end

---Register with whichever phone is running. Registrations live in the phone's client memory, so
---this runs again whenever a phone (re)starts. The deployment disables sd-phone's legacy native
---SCOOT route, leaving this external app as the single full-fidelity implementation.
local function register()
    if not CFG.Enabled then return end
    local def = manifest()
    if GetResourceState('sd-phone') == 'started' and CFG.App.ForceCustom then
        local ok, err = exports['sd-phone']:addCustomApp(def)
        if ok then log.debug('app', 'registered with sd-phone') else log.warn('app', 'sd-phone refused the app: %s', tostring(err)) end
    end
    if GetResourceState('lb-phone') == 'started' and not lbIsShim() then
        local ok = pcall(function() exports['lb-phone']:AddCustomApp(def) end)
        if ok then log.debug('app', 'registered with lb-phone') else log.warn('app', 'lb-phone refused the app') end
    end
end

---Wait for either phone to start, then register the app once it has settled.
CreateThread(function()
    while GetResourceState('sd-phone') ~= 'started' and GetResourceState('lb-phone') ~= 'started' do Wait(1000) end
    Wait(1000)
    register()
end)

---A phone (re)started and lost its registrations: register the app with it again.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'sd-phone' and resource ~= 'lb-phone' then return end
    Wait(1000)
    register()
end)

---Remove the app from sd-phone when this resource stops, so no dead icon is left behind.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    if GetResourceState('sd-phone') == 'started' then pcall(function() exports['sd-phone']:removeCustomApp(CFG.App.identifier) end) end
end)

---Push a phone notification for this app, through whichever phone is running.
---@param title string
---@param body string
local function notify(title, body)
    if GetResourceState('sd-phone') == 'started' then
        exports['sd-phone']:showNotification({ title = title, body = body, app = CFG.App.identifier, appId = CFG.App.identifier })
    elseif GetResourceState('lb-phone') == 'started' then
        pcall(function() exports['lb-phone']:SendNotification({ app = CFG.App.identifier, title = title, content = body }) end)
    end
end

---@type table<string, string> Plain pass-throughs from the app page: NUI verb -> server verb.
local PASS = { nearby = 'nearby', history = 'history' }
---Register one NUI callback per pass-through verb, each relaying straight to the server.
for nuiVerb, serverVerb in pairs(PASS) do
    RegisterNUICallback('scoot:app:' .. nuiVerb, function(data, cb)
        cb(request(serverVerb, data))
    end)
end

---NUI callback: unlock a scooter. The server checks distance, availability and the fee.
RegisterNUICallback('scoot:app:rent', function(data, cb)
    local reply = request('rent', data)
    if reply.success and reply.data and reply.data.ride then
        notify(locale('notify.title'), locale('notify.ride_started', reply.data.ride.plate))
    end
    cb(reply)
end)

---NUI callback: order a scooter from the station the player stands at.
RegisterNUICallback('scoot:app:rentHere', function(data, cb)
    local reply = request('rentHere', data)
    if reply.success then notify(locale('notify.title'), locale('notify.dispensing')) end
    cb(reply)
end)

---NUI callback: end the ride and bill it.
RegisterNUICallback('scoot:app:finish', function(_, cb)
    local reply = request('finish')
    if reply.success and reply.data and reply.data.receipt then
        local r = reply.data.receipt
        notify(locale('notify.title'), locale('notify.ride_ended', r.minutes, CFG.Currency, r.cost))
    end
    cb(reply)
end)

---NUI callback: GPS waypoint to a scooter.
RegisterNUICallback('scoot:app:waypoint', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x, y)
        lib.notify({ title = locale('notify.title'), description = locale('notify.waypoint'), type = 'inform' })
    end
    cb({ success = x ~= nil })
end)

---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'
---@type table Bunker cache + GlobalState publisher (server/scoot/bunkers.lua).
local bunkers = require 'server.scoot.bunkers'
---@type table Scooter fleet: spawn, sync, CRUD (server/scoot/scooters.lua).
local scooters = require 'server.scoot.scooters'
---@type table Charging stations: cache, slots, GlobalState publisher (server/scoot/stations.lua).
local stations = require 'server.scoot.stations'
---@type table Rides, billing and idle locks (server/scoot/rentals.lua).
local rentals = require 'server.scoot.rentals'
---@type table Battery drain, charging and flat recovery (server/scoot/battery.lua).
local battery = require 'server.scoot.battery'
---@type table Live handling profiles published to every client (server/scoot/handling.lua).
local handling = require 'server.scoot.handling'
---@type table Live setting overrides applied to the config before anything else boots (server/scoot/settings.lua).
local settings = require 'server.scoot.settings'

---Every server/scoot module (admin and app included) is loaded by fxmanifest.lua before this file,
---so the requires above resolve from package.preload; see client/main.lua for why.
lib.locale(config.Locale)

---Boot inside a thread + pcall so a database that is still coming up degrades to empty caches
---and a red console line instead of a dead resource. oxmysql is up by the time this runs.
CreateThread(function()
    local ok, err = pcall(function()
        store.ensureSchema()
        settings.boot()
        bunkers.boot()
        stations.boot()
        scooters.boot()
        if config.Rentals.Enabled then rentals.boot() end
        battery.boot()
        handling.boot()
    end)
    if not ok then
        log.error(nil, 'boot failed: %s', tostring(err))
        return
    end
    log.info(nil, 'ready: %d bunkers, %d stations, %d scooters', bunkers.count(), stations.count(), scooters.count())
end)


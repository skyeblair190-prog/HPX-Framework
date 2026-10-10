-- Aggregate config root, loaded by both sides via `require 'configs.config'`.
-- Scope-by-folder like the other sd-* resources: configs/shared/ is read by client + server.
-- There is no configs/server/ here - nothing in this resource is sensitive enough to keep off
-- the client - so the server-only deep-merge step the siblings do is deliberately absent.
local config = {
    Locale = 'en', -- lib.locale loads locales/<Locale>.json, falling back to en per-key
    Debug = true, -- log.debug lines in the console; leave off in production
    VehicleKeys = 'auto', -- key script renters get keys from: 'auto' detects it, 'none' hands out no keys, or a resource name to force one (list in bridge/server/keys.lua)

    Admin = require 'configs.shared.admin', -- command, permission group, placement + map tuning
    Bunkers = require 'configs.shared.bunkers', -- prop model, streaming + rise animation, first-boot seed
    Scooters = require 'configs.shared.scooters', -- vehicle model, plates, colours, spawn offset, position sync
    Rentals = require 'configs.shared.rentals', -- fees, distances, idle lock, and the phone app manifest
    Stations = require 'configs.shared.stations', -- charging station prop family, dock offsets, streaming
    Battery = require 'configs.shared.battery', -- drain, charge and the rent threshold
    Handling = require 'configs.shared.handling', -- live handling editor: editable fields, preset dials, templates
    Storage = require 'configs.shared.storage', -- storage box: lid target + stash
}

return config

---Live settings on the client: the server publishes its overrides and they are written into this
---client's config tables, so prices, charging rules and distances match what the server bills.
---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Editable setting catalogue + apply helpers (shared/settings.lua).
local shared = require 'shared.settings'

---@type string GlobalState key the server publishes overrides under.
local STATE_KEY = 'sd_scoot:settings'
---@type table<string, any> This client's file values, captured before any override.
local defaults = shared.capture(config)

---Reset config to the file values, apply the given overrides on top and fire settingsApplied.
---@param overrides table|nil
local function applyOverrides(overrides)
    shared.apply(config, defaults, type(overrides) == 'table' and overrides or {})
    TriggerEvent('sd_scoot:client:settingsApplied')
end

applyOverrides(GlobalState[STATE_KEY])

---Re-apply the settings whenever the server publishes a new set of overrides.
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    applyOverrides(value)
end)

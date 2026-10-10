---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'
---@type table Editable setting catalogue + apply helpers (shared/settings.lua).
local shared = require 'shared.settings'

---@type string GlobalState key clients read the overrides from.
local STATE_KEY = 'sd_scoot:settings'

local settings = {}

---@type table<string, any> File values, captured before any override is applied.
local defaults = shared.capture(config)
---@type table<string, { value: any, updatedBy: string|nil, updatedAt: integer|nil }>
local overrides = {}

---Override values keyed by path, without their audit fields.
---@return table<string, any>
local function overrideValues()
    local out = {}
    for path, o in pairs(overrides) do out[path] = o.value end
    return out
end

---Apply the current overrides to the live config and publish them to GlobalState so clients match.
local function publish()
    local values = overrideValues()
    shared.apply(config, defaults, values)
    GlobalState[STATE_KEY] = values
end

---Load stored overrides, apply them to the live config and publish them. Called first at boot, so
---every module that boots after it reads the overridden values.
function settings.boot()
    overrides = {}
    for _, row in ipairs(store.settings.all()) do
        local def = shared.byPath[row.path]
        if def then
            local okay, decoded = pcall(json.decode, row.value)
            local value = okay and shared.clean(def, decoded) or nil
            if value ~= nil then overrides[row.path] = { value = value, updatedBy = row.updatedBy, updatedAt = row.updatedAt } end
        end
    end
    publish()
    local n = 0
    for _ in pairs(overrides) do n = n + 1 end
    if n > 0 then log.info('settings', 'applied %d live setting override(s)', n) end
end

---Everything the Settings tab shows.
---@return table
function settings.bundle()
    local list = {}
    for _, def in ipairs(shared.defs) do
        local o = overrides[def.path]
        list[#list + 1] = {
            path = def.path, group = def.group, type = def.type, min = def.min, max = def.max, step = def.step,
            options = def.options, unit = def.unit,
            default = defaults[def.path], value = o and o.value or defaults[def.path],
            overridden = o ~= nil, updatedBy = o and o.updatedBy or nil, updatedAt = o and o.updatedAt or nil,
        }
    end
    return { settings = list, currency = config.Rentals.Currency }
end

---Save a set of changes. A value equal to the file default clears the override.
---@param values table<string, any>
---@param by string
---@return string[]|nil changed human-readable "Path: old -> new" lines
---@return string|nil errKey
function settings.save(values, by)
    if type(values) ~= 'table' then return nil, 'err.bad_setting' end
    local changed = {}
    for path, raw in pairs(values) do
        local def = shared.byPath[path]
        if not def then return nil, 'err.bad_setting' end
        local value = shared.clean(def, raw)
        if value == nil then return nil, 'err.bad_setting' end
        local before = overrides[path] and overrides[path].value
        if before == nil then before = defaults[path] end
        if value ~= before then
            if value == defaults[path] then
                overrides[path] = nil
                store.settings.clear(path)
            else
                overrides[path] = { value = value, updatedBy = by, updatedAt = os.time() }
                store.settings.set(path, json.encode(value), by)
            end
            changed[#changed + 1] = ('%s: %s -> %s'):format(path, tostring(before), tostring(value))
        end
    end
    if #changed > 0 then publish() end
    return changed
end

---Drop every override: the file values apply again.
---@return integer cleared
function settings.resetAll()
    local n = 0
    for path in pairs(overrides) do
        store.settings.clear(path)
        n = n + 1
    end
    overrides = {}
    publish()
    return n
end

---Register the module so `require 'server.scoot.settings'` returns this table.
---@return table
package.preload['server.scoot.settings'] = function() return settings end

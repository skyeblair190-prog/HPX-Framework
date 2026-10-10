---Live settings: config values an admin can change from the panel without a restart. Server and
---client both hold the same config tables every module reads through (`CFG = config.Rentals` is a
---reference, not a copy), so writing an override into them takes effect on the next read.
---Only what is listed here is editable; anything a module caches at load time is deliberately left out.

---@class SettingDef
---@field path string dotted path under the config root
---@field group string panel section
---@field type 'int'|'number'|'bool'|'enum'
---@field min number|nil
---@field max number|nil
---@field step number|nil
---@field options string[]|nil
---@field unit string|nil short suffix the panel shows ('$', 'm', 'min', '%', '%/min')

local settings = {}

---@type SettingDef[]
settings.defs = {
    { path = 'Rentals.UnlockFee', group = 'pricing', type = 'int', min = 0, max = 10000, step = 1, unit = '$' },
    { path = 'Rentals.Account', group = 'pricing', type = 'enum', options = { 'bank', 'cash' } },
    { path = 'Rentals.MaxRideMinutes', group = 'rides', type = 'int', min = 5, max = 1440, step = 5, unit = 'min' },
    { path = 'Rentals.LockIdle', group = 'rides', type = 'bool' },
    { path = 'Rentals.RentDistance', group = 'rides', type = 'number', min = 1, max = 100, step = 0.5, unit = 'm' },
    { path = 'Rentals.StationDistance', group = 'rides', type = 'number', min = 1, max = 100, step = 0.5, unit = 'm' },
    { path = 'Rentals.DockDistance', group = 'rides', type = 'number', min = 1, max = 100, step = 0.5, unit = 'm' },
    { path = 'Rentals.NearbyRadius', group = 'rides', type = 'number', min = 50, max = 5000, step = 50, unit = 'm' },
    { path = 'Battery.DrainPerMinute', group = 'battery', type = 'number', min = 0, max = 50, step = 0.1, unit = '%/min' },
    { path = 'Battery.ChargePerMinute', group = 'battery', type = 'number', min = 0.1, max = 100, step = 0.5, unit = '%/min' },
    { path = 'Battery.MinToRent', group = 'battery', type = 'int', min = 0, max = 100, step = 1, unit = '%' },
    { path = 'Battery.FlatRecoverMinutes', group = 'battery', type = 'int', min = 1, max = 1440, step = 1, unit = 'min' },
    { path = 'Battery.AdoptedLevel', group = 'battery', type = 'int', min = 0, max = 100, step = 1, unit = '%' },
    { path = 'Battery.Paid.Enabled', group = 'charging', type = 'bool' },
    { path = 'Battery.Paid.PricePerPercent', group = 'charging', type = 'number', min = 0, max = 100, step = 0.01, unit = '$' },
    { path = 'Battery.Paid.MinimumFee', group = 'charging', type = 'int', min = 0, max = 10000, step = 1, unit = '$' },
    { path = 'Battery.Paid.Step', group = 'charging', type = 'int', min = 1, max = 50, step = 1, unit = '%' },
    { path = 'Battery.Paid.RefundOnStop', group = 'charging', type = 'bool' },
    { path = 'Battery.Paid.Account', group = 'charging', type = 'enum', options = { 'bank', 'cash' } },
    { path = 'Bunkers.Stock', group = 'fleet', type = 'int', min = 0, max = 100, step = 1 },
}

---@type table<string, SettingDef>
settings.byPath = {}
for _, def in ipairs(settings.defs) do settings.byPath[def.path] = def end

---Walk a dotted path to the table holding its last key.
---@param root table
---@param path string
---@return table|nil parent, string key
local function locate(root, path)
    local parent, key = root, nil
    for part in path:gmatch('[^%.]+') do
        if key then
            parent = parent[key]
            if type(parent) ~= 'table' then return nil, part end
        end
        key = part
    end
    return parent, key
end

---Read a config value by dotted path, e.g. Bunkers.Stock.
---@param root table config root
---@param path string
---@return any
function settings.get(root, path)
    local parent, key = locate(root, path)
    return parent and parent[key]
end

---Write a config value by dotted path; does nothing when a parent table is missing.
---@param root table
---@param path string
---@param value any
function settings.set(root, path, value)
    local parent, key = locate(root, path)
    if parent then parent[key] = value end
end

---Validate and clamp a value for a setting; nil when unusable.
---@param def SettingDef
---@param value any
---@return any
function settings.clean(def, value)
    if def.type == 'bool' then
        if type(value) == 'boolean' then return value end
        return nil
    elseif def.type == 'enum' then
        for _, option in ipairs(def.options) do
            if option == value then return value end
        end
        return nil
    end
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.min(def.max, math.max(def.min, n))
    if def.type == 'int' then return math.floor(n + 0.5) end
    return n + 0.0
end

---Snapshot every editable setting's current value (taken before any override: the file defaults).
---@param root table
---@return table<string, any>
function settings.capture(root)
    local out = {}
    for _, def in ipairs(settings.defs) do out[def.path] = settings.get(root, def.path) end
    return out
end

---Make the config match `defaults` with `overrides` on top: an override that was removed goes back
---to its file value. Unknown paths and unusable values are ignored.
---@param root table
---@param defaults table<string, any>
---@param overrides table<string, any>|nil
function settings.apply(root, defaults, overrides)
    overrides = overrides or {}
    for _, def in ipairs(settings.defs) do
        local value = overrides[def.path]
        if value ~= nil then value = settings.clean(def, value) end
        if value == nil then value = defaults[def.path] end
        settings.set(root, def.path, value)
    end
end

---Register the module so `require 'shared.settings'` returns this table.
---@return table
package.preload['shared.settings'] = function() return settings end

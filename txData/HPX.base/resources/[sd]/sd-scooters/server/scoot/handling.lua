---@type table sd_scoot config root (configs/config.lua).
local config = require 'configs.config'
---@type table Console log helper (shared/log.lua): tagged, colour-coded prints.
local log = require 'shared.log'
---@type table Schema + SQL (server/scoot/store.lua).
local store = require 'server.scoot.store'

---@type table Handling editor config (configs/shared/handling.lua).
local CFG = config.Handling
---@type string GlobalState key clients read the resolved handling from.
local STATE_KEY = 'sd_scoot:handling'
---@type number Values closer than this to the baseline are dropped from a profile.
local EPSILON = 1e-4

---@type table Module table; returned at end of file.
local handling = {}

---@type table<string, table> Catalogue by field name: { name, class, type, unit?, min, max, step, group }.
local fields = {}
---@type string[] Field names in panel order.
local order = {}
---@type table<string, boolean> Horn ids from Config.Handling.Horns.
local horns = {}
for _, h in ipairs(CFG.Horns or {}) do horns[h.id] = true end
---@type string The horn a profile gets when it does not pick one.
local DEFAULT_HORN = horns[CFG.DefaultHorn] and CFG.DefaultHorn or 'none'
for _, group in ipairs(CFG.Groups) do
    for _, f in ipairs(group.fields) do
        local entry = { name = f.name, class = f.class or 'CHandlingData', type = f.type or 'float', unit = f.unit, min = f.min, max = f.max, step = f.step, group = group.id }
        fields[f.name] = entry
        order[#order + 1] = f.name
    end
end

---@type table<string, number|table> Baseline values parsed from data/handling.meta.
local defaults = {}
---@type table<integer, table> Profiles by id: { id, name, values, active, updatedBy, updatedAt }.
local profiles = {}
---@type integer Active profile id, 0 when handling.meta applies unmodified.
local activeId = 0
---@type integer Bumped on every publish so clients re-apply.
local rev = 0

---Read the editable fields' baseline out of data/handling.meta (the SD_SCOOT item).
local function loadDefaults()
    local xml = LoadResourceFile(GetCurrentResourceName(), 'data/handling.meta') or ''
    for _, name in ipairs(order) do
        local f = fields[name]
        if f.type == 'horn' then
            defaults[name] = DEFAULT_HORN
        elseif f.type == 'vector' then
            local x, y, z = xml:match('<' .. name .. ' x="([-%d%.]+)" y="([-%d%.]+)" z="([-%d%.]+)"')
            defaults[name] = { x = tonumber(x) or 0.0, y = tonumber(y) or 0.0, z = tonumber(z) or 0.0 }
        else
            local v = tonumber(xml:match('<' .. name .. ' value="([-%d%.]+)"'))
            if not v then
                log.warn('handling', '%s is missing from data/handling.meta; using the slider minimum', name)
                v = f.min
            end
            defaults[name] = v
        end
    end
end

---Clamp and normalise one incoming value; nil when it is not usable.
---@param f table catalogue entry
---@param v any
---@return number|table|nil
local function clean(f, v)
    if f.type == 'horn' then
        return type(v) == 'string' and horns[v] and v or nil
    end
    if f.type == 'vector' then
        if type(v) ~= 'table' then return nil end
        local out = {}
        for _, axis in ipairs({ 'x', 'y', 'z' }) do
            local n = tonumber(v[axis])
            if not n or n ~= n then return nil end
            out[axis] = math.min(f.max, math.max(f.min, n))
        end
        return out
    end
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.min(f.max, math.max(f.min, n))
    if f.type == 'int' then n = math.floor(n + 0.5) end
    return n
end

---Compare two handling values, with EPSILON tolerance for numbers and vectors.
---@param a number|table|string|nil
---@param b number|table|string|nil
---@return boolean
local function same(a, b)
    if a == nil or b == nil then return a == b end
    if type(a) == 'string' or type(b) == 'string' then return a == b end
    if type(a) == 'table' and type(b) == 'table' then
        return math.abs(a.x - b.x) < EPSILON and math.abs(a.y - b.y) < EPSILON and math.abs(a.z - b.z) < EPSILON
    end
    if type(a) ~= type(b) then return false end
    return math.abs(a - b) < EPSILON
end

---Keep only known fields that differ from the baseline, clamped into range.
---@param values any
---@return table<string, number|table|string>
local function sanitizeValues(values)
    local out = {}
    if type(values) ~= 'table' then return out end
    for name, v in pairs(values) do
        local f = fields[name]
        if f then
            local c = clean(f, v)
            if c ~= nil and not same(c, defaults[name]) then out[name] = c end
        end
    end
    return out
end

---Baseline with a profile's overrides laid over it: every editable field has a value.
---@param overrides table|nil
---@return table<string, number|table>
local function resolve(overrides)
    local out = {}
    for _, name in ipairs(order) do
        local v = overrides and overrides[name]
        if v == nil then v = defaults[name] end
        out[name] = v
    end
    return out
end

---Push the active values to every client. Disabled or no active profile publishes the baseline, so
---scooters an earlier profile touched go back to handling.meta.
local function publish()
    rev = rev + 1
    local active = CFG.Enabled and profiles[activeId] or nil
    GlobalState[STATE_KEY] = {
        rev = rev,
        profileId = active and active.id or 0,
        name = active and active.name or nil,
        values = resolve(active and active.values),
    }
    log.info('handling', 'published rev %d: %s', rev, active and ('profile #' .. active.id .. ' ' .. active.name) or 'handling.meta baseline')
end

---Decode stored JSON, falling back to an empty table when it is missing or malformed.
---@param raw string|nil
---@return table
local function decode(raw)
    local okay, value = pcall(json.decode, raw or '')
    return okay and type(value) == 'table' and value or {}
end

---Load profiles from the database, parse the baseline and publish. Called once at boot.
function handling.boot()
    loadDefaults()
    profiles, activeId = {}, 0
    for _, row in ipairs(store.handling.all()) do
        local p = { id = row.id, name = row.name, values = sanitizeValues(decode(row.values)), active = row.active == 1 or row.active == true, updatedBy = row.updatedBy, updatedAt = row.updatedAt }
        profiles[p.id] = p
        if p.active then activeId = p.id end
    end
    publish()
end

---The profile list the panel renders, oldest first.
---@return table[]
local function profileList()
    local list = {}
    for _, p in pairs(profiles) do
        list[#list + 1] = { id = p.id, name = p.name, values = p.values, active = p.id == activeId, updatedBy = p.updatedBy, updatedAt = p.updatedAt }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---Everything the Handling tab needs in one reply.
---@return table
function handling.bundle()
    local groups = {}
    for _, group in ipairs(CFG.Groups) do
        local list = {}
        for _, f in ipairs(group.fields) do
            local e = fields[f.name]
            local entry = { name = e.name, class = e.class, type = e.type, unit = e.unit, min = e.min, max = e.max, step = e.step, default = defaults[e.name] }
            if e.type == 'horn' then
                entry.options = {}
                for _, h in ipairs(CFG.Horns or {}) do entry.options[#entry.options + 1] = { id = h.id, label = h.label } end
            end
            list[#list + 1] = entry
        end
        groups[#groups + 1] = { id = group.id, fields = list }
    end
    local history = {}
    for _, row in ipairs(store.handling.history(CFG.HistoryLimit)) do
        history[#history + 1] = { id = row.id, profileId = row.profileId, actor = row.actor, changes = decode(row.changes), at = row.at }
    end
    return {
        enabled = CFG.Enabled == true,
        groups = groups,
        presets = CFG.Presets,
        templates = CFG.Templates,
        profiles = profileList(),
        activeId = activeId,
        history = history,
        returnKey = CFG.ReturnKey,
        unit = config.Scooters.SpeedUnit == 'mph' and 'mph' or 'kmh',
    }
end

---Trim a profile name, or nil when it is empty or longer than 48 characters.
---@param name any
---@return string|nil
local function cleanName(name)
    name = type(name) == 'string' and name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < 1 or #name > 48 then return nil end
    return name
end

---Create a profile from the baseline, a template or another profile.
---@param data table { name, from?: 'defaults' | 'template' | 'profile', index?, id? }
---@param by string actor name
---@return table|nil profile, string|nil errKey
function handling.create(data, by)
    local name = cleanName(data.name)
    if not name then return nil, 'err.handling_name' end
    local values = {}
    if data.from == 'template' then
        local tpl = CFG.Templates[tonumber(data.index) or 0]
        if not tpl then return nil, 'err.handling_template' end
        values = sanitizeValues(tpl.values)
    elseif data.from == 'profile' then
        local src = profiles[tonumber(data.id) or 0]
        if not src then return nil, 'err.handling_profile' end
        values = sanitizeValues(src.values)
    end
    local id = store.handling.insert(name, json.encode(values), by)
    profiles[id] = { id = id, name = name, values = values, active = false, updatedBy = by, updatedAt = os.time() }
    return profiles[id]
end

---Replace a profile's overrides, log what changed and republish when it is the active one.
---@param id any
---@param values any
---@param by string
---@return table|nil changes, string|nil errKey
function handling.save(id, values, by)
    local p = profiles[tonumber(id) or 0]
    if not p then return nil, 'err.handling_profile' end
    local nextValues = sanitizeValues(values)
    local changes, count = {}, 0
    for _, name in ipairs(order) do
        local old, new = p.values[name], nextValues[name]
        if not same(old, new) then
            changes[name] = { old == nil and false or old, new == nil and false or new }
            count = count + 1
        end
    end
    if count == 0 then return {} end
    p.values, p.updatedBy, p.updatedAt = nextValues, by, os.time()
    store.handling.setValues(p.id, json.encode(nextValues), by)
    store.handling.log(p.id, by, json.encode(changes), CFG.HistoryLimit)
    if p.id == activeId then publish() end
    return changes
end

---Make a profile the active one (0 goes back to handling.meta), save it and republish.
---@param id any 0 or nil switches back to handling.meta
---@return boolean|nil done, string|nil errKey
function handling.activate(id)
    id = tonumber(id) or 0
    if id ~= 0 and not profiles[id] then return nil, 'err.handling_profile' end
    store.handling.setActive(id)
    activeId = id
    publish()
    return true
end

---Rename a profile; republishes only when it is the active one.
---@param id any
---@param name any
---@return boolean|nil done, string|nil errKey
function handling.rename(id, name)
    local p = profiles[tonumber(id) or 0]
    if not p then return nil, 'err.handling_profile' end
    name = cleanName(name)
    if not name then return nil, 'err.handling_name' end
    p.name = name
    store.handling.setName(p.id, name)
    if p.id == activeId then publish() end
    return true
end

---Delete a profile and its log; deleting the active one falls back to handling.meta.
---@param id any
---@return boolean|nil done, string|nil errKey
function handling.remove(id)
    local p = profiles[tonumber(id) or 0]
    if not p then return nil, 'err.handling_profile' end
    store.handling.delete(p.id)
    profiles[p.id] = nil
    if p.id == activeId then
        activeId = 0
        publish()
    end
    return true
end

---Put the fields one logged save changed back to what they were before it. Logged as a save of its own.
---@param logId any
---@param by string
---@return table|nil changes, string|nil errKey
function handling.undo(logId, by)
    local row = store.handling.logEntry(tonumber(logId) or 0)
    if not row then return nil, 'err.handling_history' end
    local p = profiles[row.profileId]
    if not p then return nil, 'err.handling_profile' end
    local values = {}
    for k, v in pairs(p.values) do values[k] = v end
    for name, pair in pairs(decode(row.changes)) do
        local old = type(pair) == 'table' and pair[1] or nil
        if old == false then old = nil end
        values[name] = old
    end
    return handling.save(p.id, values, by)
end

---Format a number the way handling.meta writes floats.
---@param n number
---@return string handling.meta float formatting
local function fmt(n)
    return string.format('%.6f', n)
end

---data/handling.meta with the given values written into it (anything not given keeps its file value),
---ready to paste over the file so the tuning survives without a profile.
---@param values any
---@return string
function handling.export(values)
    local resolved = resolve(sanitizeValues(values))
    local xml = LoadResourceFile(GetCurrentResourceName(), 'data/handling.meta') or ''
    for _, name in ipairs(order) do
        local f, v = fields[name], resolved[name]
        if f.type == 'horn' then
        elseif f.type == 'vector' then
            xml = xml:gsub('(<' .. name .. ' )x="[-%d%.]+" y="[-%d%.]+" z="[-%d%.]+"', function(head)
                return ('%sx="%s" y="%s" z="%s"'):format(head, fmt(v.x), fmt(v.y), fmt(v.z))
            end, 1)
        else
            local text = f.type == 'int' and tostring(math.floor(v + 0.5)) or fmt(v)
            xml = xml:gsub('(<' .. name .. ' value=")[-%d%.]+"', function(head)
                return head .. text .. '"'
            end, 1)
        end
    end
    return xml
end

---Register the module so `require 'server.scoot.handling'` returns this table.
---@return table
package.preload['server.scoot.handling'] = function() return handling end

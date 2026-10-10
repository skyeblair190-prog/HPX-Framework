local C = json.decode(LoadResourceFile(GetCurrentResourceName(), 'configs/extras.json'))
local M = { catalog = C }
---@type table<string, table<string, string>> Retired option ids mapped onto their nearest survivor.
---An id that is no longer in the catalogue fails validation, and that discards the WHOLE saved
---customisation rather than the one choice, so a scooter wearing the old amber underglow would
---lose its trim and storage with it.
local LEGACY = { lighting = { amber = 'orange' }, rear = { rack = 'none' }, trim = { lime = 'green' } }

---Unknown keys are ignored rather than refused: `out` is built only from the catalogue's own
---defaults, so a row saved before an option was retired keeps the choices that still exist.
function M.normalise(raw)
    if raw == nil then raw = {} end
    if type(raw) ~= 'table' then return nil, 'err.bad_extras' end
    local out, fee = {}, 0
    for key, fallback in pairs(C.defaults) do
        local value = raw[key]; if value == nil then value = fallback end
        if type(value) ~= type(fallback) then return nil, 'err.bad_extras' end
        out[key] = value
    end
    for key, map in pairs(LEGACY) do
        local swap = map[out[key]]
        if swap then out[key] = swap end
    end
    for _, key in ipairs({'rear','trim','lighting','box'}) do
        local found = false
        for _, item in ipairs(C[key]) do if item.id == out[key] then found = true; fee = fee + item.fee; break end end
        if not found then return nil, 'err.bad_extras' end
    end
    return out, fee
end
---Decode a stored customisation (JSON string or table) into a valid one, falling back to the
---catalogue defaults when it is missing or invalid.
---@param raw string|table|nil
---@return table
function M.decode(raw)
    if type(raw) == 'string' then local ok,value=pcall(json.decode,raw);raw=ok and value or nil end
    local value = M.normalise(raw); return value or M.normalise(nil)
end
---Register the module so `require 'shared.extras'` returns this table.
---@return table
package.preload['shared.extras'] = function() return M end

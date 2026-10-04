---@class LogData
---@field source? number
---@field event? string
---@field message string

---@param data LogData
local function log(data)
    local who = data.source and (' [%s]'):format(data.source) or ''
    print(('[hpx_garages][%s]%s %s'):format(data.event or 'info', who, data.message))
end

return { log = log }

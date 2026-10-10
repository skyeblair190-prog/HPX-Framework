local Notifier = {}

--- Normalizes a raw type string into one of the supported notification types.
--- @param rawType string|nil
--- @return string
function Notifier.resolveType(rawType)
    local normalized = string.lower(tostring(rawType or Config.DefaultType))
    return Config.Types[normalized] or Config.DefaultType
end

--- Clamps a duration value between the configured min/max bounds.
--- @param rawDuration number|nil
--- @return number
function Notifier.resolveDuration(rawDuration)
    local duration = tonumber(rawDuration) or Config.DefaultDuration
    return math.max(Config.MinDuration, math.min(duration, Config.MaxDuration))
end

--- Sends a notification to the NUI layer.
--- @param message string
--- @param notifyType string|nil
--- @param duration number|nil
function Notifier.send(message, notifyType, duration)
    SendNUIMessage({
        action   = 'notify',
        message  = tostring(message or ''),
        type     = Notifier.resolveType(notifyType),
        duration = Notifier.resolveDuration(duration)
    })
end

exports('Notify', Notifier.send)

RegisterNetEvent('codera-notify:notify', function(message, notifyType, duration)
    Notifier.send(message, notifyType, duration)
end)

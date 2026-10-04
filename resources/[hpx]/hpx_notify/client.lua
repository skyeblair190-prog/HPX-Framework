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

--------------------------------------------------------------------------------
-- Test / preview commands
--------------------------------------------------------------------------------

local PreviewCommands = {
    {
        name           = 'notifysuccess',
        type           = 'success',
        defaultMessage = 'Action completed successfully'
    },
    {
        name           = 'notifyinform',
        type           = 'inform',
        defaultMessage = 'Here is something you should know'
    },
    {
        name           = 'notifyerror',
        type           = 'error',
        defaultMessage = 'That action could not be completed'
    }
}

for _, cmd in ipairs(PreviewCommands) do
    RegisterCommand(cmd.name, function(_, args)
        local message = #args > 0 and table.concat(args, ' ') or cmd.defaultMessage
        Notifier.send(message, cmd.type, Config.DefaultDuration)
    end, false)
end

RegisterCommand('notifyall', function()
    for _, cmd in ipairs(PreviewCommands) do
        Notifier.send(cmd.defaultMessage, cmd.type, 10000)
        Citizen.Wait(Config.PreviewGap)
    end
end, false)

RegisterKeyMapping(
    'notifyall',
    'Preview all Codera notifications',
    'keyboard',
    Config.PreviewKey
)

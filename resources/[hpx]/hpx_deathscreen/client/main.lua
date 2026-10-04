local visible = false


local function Update(data)
    data = data or {}
    local texts = Config.Texts
    visible = true
    SendNUIMessage({
        action = 'update',
        position = Config.Position,
        title = data.title or (data.state == 'incapacitated' and texts.incapacitated or texts.dead),
        subtitle = data.subtitle or texts.doctorWait,
        timer = data.timer or '00:00',
        showTimer = data.showTimer ~= false,
        showRespawn = data.showRespawn or false,
        holdTime = data.holdTime or Config.HoldTime,
        holdKey = Config.HoldKey,
        holdPrefix = texts.holdPrefix,
        holdSuffix = texts.holdSuffix
    })
end

local function Hide()
    visible = false
    SendNUIMessage({ action = 'hide' })
end

local function SetHold(seconds)
    SendNUIMessage({ action = 'updateHold', holdTime = seconds })
end

exports('Update', Update)
exports('Hide', Hide)
exports('SetHold', SetHold)
exports('IsVisible', function() return visible end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Hide() end
end)

if Config.Debug then
    RegisterCommand('deathscreen_test', function(_, args)
        local mode = args[1] or 'dead'
        if mode == 'respawn' then
            Update({ state = 'dead', showRespawn = true, showTimer = false })
        else
            Update({ state = mode, timer = '05:00' })
        end
    end, false)
    RegisterCommand('deathscreen_hide', Hide, false)
end


local function FormatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    return string.format('%02d:%02d', seconds // 60, seconds % 60)
end

local function RegisterIntegrationEvents()
    local cfg = Config.Integrations
    if not cfg or not cfg.Enabled then return end

    for _, entry in ipairs(cfg.IncapacitatedEvents or {}) do
        local name = type(entry) == 'table' and entry.name or entry
        local timeArg = type(entry) == 'table' and entry.timeArg or nil
        if name then
            RegisterNetEvent(name)
            AddEventHandler(name, function(...)
                local args = { ... }
                local seconds = timeArg and args[timeArg] or nil
                Update({
                    state = 'incapacitated',
                    timer = seconds and FormatTime(seconds) or nil
                })
            end)
        end
    end

    for _, entry in ipairs(cfg.DeadEvents or {}) do
        local name = type(entry) == 'table' and entry.name or entry
        local timeArg = type(entry) == 'table' and entry.timeArg or nil
        if name then
            RegisterNetEvent(name)
            AddEventHandler(name, function(...)
                local args = { ... }
                local seconds = timeArg and args[timeArg] or nil
                Update({
                    state = 'dead',
                    timer = seconds and FormatTime(seconds) or nil
                })
            end)
        end
    end

    for _, entry in ipairs(cfg.ReviveEvents or {}) do
        local name = type(entry) == 'table' and entry.name or entry
        if name then
            RegisterNetEvent(name)
            AddEventHandler(name, function()
                Hide()
            end)
        end
    end
end

RegisterIntegrationEvents()

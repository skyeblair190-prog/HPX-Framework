---@type FrameworkInfo Detected framework descriptor (bridge.shared.framework).
local framework = require 'bridge.shared.framework'

---@type table Player helper module returned to consumers.
local player = {}

---Resolves a framework-native player object for the given source, nil without a framework.
---@param source number
---@return any|nil
function player.get(source)
    if framework.name == 'hpx' then return framework.core:GetPlayer(source) end
    if framework.name == 'qb' then return framework.core.Functions.GetPlayer(source) end
    if framework.name == 'esx' then return framework.core.GetPlayerFromId(source) end
    return nil
end

---The player's persistent identifier: citizenid on QBCore/Qbox, identifier on ESX, and the
---license as a last resort so rentals still key on something stable.
---@param source number
---@return string|nil
function player.getIdentifier(source)
    local p = player.get(source)
    if p then
        if framework.name == 'hpx' then return p.citizenid end
        if framework.name == 'qb' then return p.PlayerData.citizenid end
        if framework.name == 'esx' then return p.identifier end
    end
    return GetPlayerIdentifierByType(source, 'license')
end

---Friendly "First Last" name, or the server name when the framework has none.
---@param source number
---@return string
function player.getName(source)
    local p = player.get(source)
    if p and framework.name == 'hpx' then
        local ci = p.charinfo or {}
        if ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    elseif p and framework.name == 'qb' then
        local ci = p.PlayerData.charinfo or {}
        if ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    elseif p and framework.name == 'esx' and p.getName then
        return p.getName()
    end
    return GetPlayerName(source) or 'Unknown'
end

return player

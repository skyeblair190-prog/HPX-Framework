if not Framework.HPX() then return end

local function getPlayer(src)
    return exports.hpx_core:GetPlayer(src)
end

local function toGroup(group, fallbackName)
    group = type(group) == "table" and group or {}
    return {
        name = group.name or fallbackName,
        label = group.label or group.name or fallbackName,
        grade = { level = tonumber(group.grade) or 0 }
    }
end

function Framework.GetPlayerID(src)
    local player = getPlayer(src)
    return player and player.citizenid
end

function Framework.HasMoney(src, type, money)
    return (tonumber(exports.hpx_core:GetMoney(src, type)) or 0) >= money
end

function Framework.RemoveMoney(src, type, money)
    return exports.hpx_core:RemoveMoney(src, type, money, "illenium-appearance") == true
end

function Framework.GetJob(src)
    local player = getPlayer(src)
    return toGroup(player and player.job, "unemployed")
end

function Framework.GetGang(src)
    local player = getPlayer(src)
    return toGroup(player and player.gang, "none")
end

function Framework.SaveAppearance(appearance, citizenID)
    Database.PlayerSkins.UpdateActiveField(citizenID, 0)
    Database.PlayerSkins.DeleteByModel(citizenID, appearance.model)
    Database.PlayerSkins.Add(citizenID, appearance.model, json.encode(appearance), 1)
end

function Framework.GetAppearance(citizenID, model)
    local result = Database.PlayerSkins.GetByCitizenID(citizenID, model)
    if result then
        return json.decode(result)
    end
end

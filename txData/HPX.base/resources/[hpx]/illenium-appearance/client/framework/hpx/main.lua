if not Framework.HPX() then return end

local client = client

local PlayerData = {}

local function setClientParams()
    client.job = PlayerData.job or { name = "unemployed", label = "Unemployed", grade = 0, onduty = false }
    client.gang = PlayerData.gang or { name = "none", label = "None", grade = 0 }
    client.citizenid = PlayerData.citizenid
end

setClientParams()

function Framework.GetPlayerGender()
    local gender = PlayerData.charinfo and PlayerData.charinfo.gender
    if type(gender) == "string" then
        gender = gender:lower()
    end
    if gender == "female" or gender == "f" or gender == 1 then
        return "Female"
    end
    return "Male"
end

function Framework.UpdatePlayerData()
    if exports.hpx_core:IsLoaded() then
        PlayerData = exports.hpx_core:GetPlayerData()
    end
    setClientParams()
end

function Framework.HasTracker()
    return PlayerData.metadata and PlayerData.metadata.tracker or false
end

function Framework.CheckPlayerMeta()
    local metadata = PlayerData.metadata or {}
    return LocalPlayer.state.isDead or metadata.isdead or metadata.inlaststand or metadata.ishandcuffed or IsPedCuffed(cache.ped)
end

function Framework.IsPlayerAllowed(citizenid)
    return citizenid == PlayerData.citizenid
end

-- hpx_core has no shared job/gang grade definitions to list
function Framework.GetRankInputValues()
    return {}
end

function Framework.GetJobGrade()
    return tonumber(client.job and client.job.grade) or 0
end

function Framework.GetGangGrade()
    return tonumber(client.gang and client.gang.grade) or 0
end

function Framework.CachePed()
    return nil
end

function Framework.RestorePlayerArmour()
    Framework.UpdatePlayerData()
    local armor = PlayerData.metadata and tonumber(PlayerData.metadata.armor)
    if armor then
        Wait(1000)
        SetPedArmour(cache.ped, armor)
    end
end

RegisterNetEvent("hpx:client:characterLoaded", function(data, isNew)
    if type(data) == "table" then
        PlayerData = data
    end
    setClientParams()

    if isNew then
        return InitializeCharacter(Framework.GetGender(true))
    end

    InitAppearance()
end)

RegisterNetEvent("hpx:client:setPlayerData", function(data)
    if type(data) ~= "table" then return end

    local previousJob = client.job and client.job.name
    local previousGang = client.gang and client.gang.name

    PlayerData = data
    setClientParams()

    if previousJob ~= client.job.name or previousGang ~= client.gang.name then
        ResetBlips()
    end
end)

RegisterNetEvent("hpx:client:characterUnloaded", function()
    PlayerData = {}
    setClientParams()
    ResetBlips()
end)

AddEventHandler("playerSpawned", function()
    if exports.hpx_core:IsLoaded() then
        InitAppearance()
    end
end)

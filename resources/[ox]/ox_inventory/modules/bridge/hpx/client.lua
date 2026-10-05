local function getGroups(job, gang)
    local groups = {}

    if type(job) == 'table' and job.name then
        groups[job.name] = tonumber(job.grade) or 0
    end

    if type(gang) == 'table' and gang.name and gang.name ~= 'none' then
        groups[gang.name] = tonumber(gang.grade) or 0
    end

    return groups
end

RegisterNetEvent('hpx:client:characterUnloaded', function()
    client.onLogout()
end)

RegisterNetEvent('hpx:client:setPlayerData', function(data)
    if not PlayerData.loaded or type(data) ~= 'table' then return end
    client.setPlayerData('groups', getGroups(data.job, data.gang))
end)

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    local playerState = LocalPlayer.state
    for name, value in pairs(values) do
        -- compatibility for ESX style values
        if value > 100 or value < -100 then
            value = value * 0.0001
        end

        playerState:set(name, lib.math.clamp((playerState[name] or 100) + value, 0, 100), true)
    end
end

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
    TriggerServerEvent('hpx:server:status', values)
end

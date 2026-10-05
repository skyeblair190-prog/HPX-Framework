local Inventory = require 'modules.inventory.server'
local HPX = exports.hpx_core

---@param job? { name: string, grade: number }
---@param gang? { name: string, grade: number }
---@return table<string, number>
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

AddEventHandler('hpx:server:characterUnloaded', function(source)
    server.playerDropped(source)
end)

local function updateGroups(source)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    local player = HPX:GetPlayer(source)
    if not player then return end

    inventory.player.groups = getGroups(player.job, player.gang)
end

AddEventHandler('hpx:server:jobChanged', updateGroups)
AddEventHandler('hpx:server:gangChanged', updateGroups)

local function setupPlayer(playerData)
    playerData.identifier = playerData.citizenid
    playerData.name = ('%s %s'):format(playerData.charinfo.firstname, playerData.charinfo.lastname)
    playerData.groups = getGroups(playerData.job, playerData.gang)
    server.setPlayerInventory(playerData)

    local accounts = Inventory.GetAccountItemCounts(playerData.source)
    if not accounts then return end

    for account in pairs(accounts) do
        local playerAccount = account == 'money' and 'cash' or account
        Inventory.SetItem(playerData.source, account, tonumber(playerData.money[playerAccount]) or 0)
    end
end

AddEventHandler('hpx:server:characterLoaded', function(source, player)
    if type(player) ~= 'table' or type(player.charinfo) ~= 'table' then return end
    player.source = source
    setupPlayer(player)
end)

AddEventHandler('hpx:server:moneyChanged', function(source, kind, amount)
    if kind ~= 'cash' or server.accounts.money == nil or not Inventory(source) then return end

    local current = Inventory.GetItem(source, 'money', false, true)
    if current ~= nil and current ~= amount then
        Inventory.SetItem(source, 'money', amount)
    end
end)

SetTimeout(500, function()
    local players = HPX:GetPlayersData()
    for i = 1, #players do setupPlayer(players[i]) end
end)

function server.UseItem(source, itemName, data)
    local cb = HPX:CanUseItem(itemName)
    return cb and cb(source, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source = player.source,
        name = player.name,
        groups = player.groups or getGroups(player.job, player.gang),
        sex = player.charinfo and player.charinfo.gender,
        dateofbirth = player.charinfo and player.charinfo.birthdate,
    }
end

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    local accounts = Inventory.GetAccountItemCounts(inv)
    if not accounts then return end

    for account, amount in pairs(accounts) do
        account = account == 'money' and 'cash' or account
        if HPX:GetMoney(inv.id, account) ~= amount then
            HPX:SetMoney(inv.id, account, amount, ('Sync %s with inventory'):format(account))
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = HPX:GetPlayer(inv.id)
    local licences = player and player.metadata and player.metadata.licences
    return licences and licences[license] or false
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = HPX:GetPlayer(inv.id)
    if not player then return end

    local licences = player.metadata and player.metadata.licences or {}

    if licences[license.name] then
        return false, 'already_have'
    elseif Inventory.GetItem(inv, 'money', false, true) < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)
    licences[license.name] = true
    player:SetMetadata('licences', licences)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    return HPX:IsGradeBoss(group, grade)
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return Entity(entityId).state.vehicleid or exports.hpx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(entityId))
end

---@diagnostic disable-next-line: duplicate-set-field
function server.getAccountMoney(inv, account)
    account = account == 'money' and 'cash' or account
    return HPX:GetMoney(inv.id, account)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.removeAccountMoney(inv, account, amount, reason)
    account = account == 'money' and 'cash' or account
    if (HPX:GetMoney(inv.id, account) or 0) < amount then return false end
    return HPX:RemoveMoney(inv.id, account, amount, reason or 'shop-purchase') == true
end

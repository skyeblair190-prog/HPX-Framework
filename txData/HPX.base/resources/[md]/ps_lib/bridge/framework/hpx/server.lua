-- HPX framework bridge for ps_lib. Added for the HPX framework (modification of ps_lib, CC BY-NC-SA 4.0, see LICENSE.md).
local core = exports.hpx_core

local function wrap(source, data)
    return {
        source = source,
        PlayerData = data,
        Functions = {
            AddMoney = function(account, amount, reason) return core:AddMoney(source, account, amount, reason) end,
            RemoveMoney = function(account, amount, reason) return core:RemoveMoney(source, account, amount, reason) end,
            SetMetaData = function(key, value) return core:SetMetadata(source, key, value) end,
        },
    }
end

function ps.getAllPlayers()
    local sources = {}
    for _, player in ipairs(core:GetPlayersData()) do sources[#sources + 1] = player.source end
    return sources
end

function ps.getPlayer(source)
    source = tonumber(source)
    if not source then return nil end
    local data = core:GetPlayer(source)
    if not data then return nil end
    data.source = source
    return wrap(source, data)
end

function ps.getPlayerByIdentifier(identifier)
    if type(identifier) ~= 'string' then return nil end
    for _, source in ipairs(ps.getAllPlayers()) do
        local data = core:GetPlayer(source)
        if data and data.citizenid == identifier then
            data.source = source
            return wrap(source, data)
        end
    end
    return nil
end

function ps.getOfflinePlayer(identifier)
    if type(identifier) ~= 'string' then return nil end
    local row = MySQL.single.await('SELECT citizenid, charinfo, money, job, gang, metadata FROM hpx_characters WHERE citizenid = ?', { identifier })
    if not row then return nil end
    return { PlayerData = {
        citizenid = row.citizenid,
        charinfo = json.decode(row.charinfo or '{}') or {},
        money = json.decode(row.money or '{}') or {},
        job = json.decode(row.job or '{}') or {},
        gang = json.decode(row.gang or '{}') or {},
        metadata = json.decode(row.metadata or '{}') or {},
    } }
end

local function resolve(source)
    return ps.getPlayer(source) or ps.getPlayerByIdentifier(source) or ps.getOfflinePlayer(source)
end

local function jobOf(source)
    local player = resolve(source)
    return player and type(player.PlayerData.job) == 'table' and player.PlayerData.job or {}
end

local function gangOf(source)
    local player = resolve(source)
    return player and type(player.PlayerData.gang) == 'table' and player.PlayerData.gang or {}
end

function ps.getLicense(source) return GetPlayerIdentifierByType(source, 'license') end
function ps.getIdentifier(source) local p = ps.getPlayer(source) return p and p.PlayerData.citizenid end

function ps.getSource(identifier)
    local player = ps.getPlayerByIdentifier(identifier)
    return player and player.source
end

function ps.getPlayerName(source)
    local player = resolve(source)
    if not player then return 'Unknown' end
    local info = player.PlayerData.charinfo or {}
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

function ps.getPlayerNameByIdentifier(identifier) return ps.getPlayerName(identifier) end
function ps.getPlayerData(source) local p = resolve(source) return p and p.PlayerData end

function ps.getMetadata(source, meta)
    local player = resolve(source)
    local metadata = player and player.PlayerData.metadata or {}
    if meta then return metadata[meta] end
    return metadata
end

function ps.getCharInfo(source, info)
    local player = resolve(source)
    local charinfo = player and player.PlayerData.charinfo or {}
    if info then return charinfo[info] end
    return charinfo
end

function ps.getJob(source) return jobOf(source) end
function ps.getJobName(source) return jobOf(source).name end
function ps.getJobType(source) return jobOf(source).type end
function ps.getJobDuty(source) return jobOf(source).onduty == true end
function ps.getJobData(source, data) return jobOf(source)[data] end
function ps.getJobGrade(source) local job = jobOf(source) return { level = tonumber(job.grade) or 0, name = job.gradelabel } end
function ps.getJobGradeLevel(source) return tonumber(jobOf(source).grade) or 0 end
function ps.getJobGradeName(source) return jobOf(source).gradelabel end
function ps.getJobGradePay(source) return jobOf(source).payment or 0 end
function ps.isBoss(source) return jobOf(source).isboss == true end

function ps.getGang(source) return gangOf(source) end
function ps.getGangName(source) return gangOf(source).name end
function ps.getGangData(source, data) return gangOf(source)[data] end
function ps.getGangGrade(source) local gang = gangOf(source) return { level = tonumber(gang.grade) or 0, name = gang.gradelabel } end
function ps.getGangGradeLevel(source) return tonumber(gangOf(source).grade) or 0 end
function ps.getGangGradeName(source) return gangOf(source).gradelabel end
function ps.isLeader(source) return gangOf(source).isboss == true end
function ps.getAllGangs() return {} end

function ps.getEntityCoords(source) return GetEntityCoords(GetPlayerPed(source)) end

function ps.getDistance(source, location)
    return #(GetEntityCoords(GetPlayerPed(source)) - vector3(location.x, location.y, location.z))
end

function ps.checkDistance(source, location, distance)
    return ps.getDistance(source, location) <= (distance or 2.5)
end

function ps.getNearbyPlayers(source, distance)
    distance = distance or 10.0
    local players = {}
    local origin = GetEntityCoords(GetPlayerPed(source))
    for _, target in ipairs(ps.getAllPlayers()) do
        local dist = #(GetEntityCoords(GetPlayerPed(target)) - origin)
        if dist < distance then
            players[#players + 1] = { value = ps.getIdentifier(target), label = ps.getPlayerName(target), source = target, distance = dist }
        end
    end
    return players
end

function ps.getJobCount(jobName)
    local count = 0
    for _, player in ipairs(core:GetPlayersData()) do
        local job = player.job
        if type(job) == 'table' and job.name == jobName and job.onduty == true then count = count + 1 end
    end
    return count
end

function ps.getJobTypeCount(jobType)
    local count = 0
    for _, player in ipairs(core:GetPlayersData()) do
        local job = player.job
        if type(job) == 'table' and job.type == jobType and job.onduty == true then count = count + 1 end
    end
    return count
end

function ps.createUseable(item, func)
    if not item or not func then return end
    core:CreateUsableItem(item, func)
end

function ps.setJob(source, job, grade)
    local player = core:GetPlayer(source)
    return player ~= nil and player.SetJob(player, job, grade or 0) == true
end

function ps.setJobDuty(source, duty) return core:SetJobDuty(source, duty == true) end

function ps.addMoney(source, account, amount, reason)
    return core:AddMoney(source, account or 'cash', amount or 0, reason or 'Added by script') == true
end

function ps.removeMoney(source, account, amount, reason)
    return core:RemoveMoney(source, account or 'cash', amount or 0, reason or 'Removed by script') == true
end

function ps.getMoney(source, account) return core:GetMoney(source, account or 'cash') or 0 end

local function jobTable()
    local jobs = {}
    for _, job in ipairs(core:GetJobs()) do jobs[job.name] = job end
    return jobs
end

function ps.getAllJobs() return jobTable() end
function ps.getJobTable(jobName) return jobTable()[jobName] end
function ps.getSharedJob(jobName) return jobTable()[jobName] end
function ps.getSharedJobData(jobName, key) local job = jobTable()[jobName] return job and job[key] end

function ps.getSharedJobGrade(jobName, grade)
    local job = jobTable()[jobName]
    if not job then return nil end
    for _, entry in ipairs(job.grades) do
        if entry.grade == tonumber(grade) then return entry end
    end
end

function ps.getSharedJobGradeData(jobName, grade, key) local entry = ps.getSharedJobGrade(jobName, grade) return entry and entry[key] end
function ps.jobExists(jobName) return jobTable()[jobName] ~= nil end
function ps.vehicleOwner() return false end
function ps.hasPermission(source, permission) return IsPlayerAceAllowed(source, permission) or core:HasPermission(source, permission) == true end
function ps.isOnline(identifier) return ps.getPlayerByIdentifier(identifier) ~= nil end

function ps.getSharedItems() return exports.ox_inventory:Items() end

function ps.getItemLabel(item)
    local data = exports.ox_inventory:Items(item)
    return data and data.label or item
end

function ps.getItemWeight(item)
    local data = exports.ox_inventory:Items(item)
    return data and data.weight or 0
end

function ps.getSharedVehicle() return nil end
function ps.getSharedVehicleData() return nil end
function ps.getSharedWeapons() return {} end
function ps.getSharedWeaponData() return nil end
function ps.getSharedGang() return nil end
function ps.getSharedGangData() return nil end
function ps.getSharedGangRankData() return nil end

for _, name in ipairs({
    'getAllPlayers','getPlayer','getPlayerByIdentifier','getOfflinePlayer','getLicense','getIdentifier','getSource','getPlayerName',
    'getPlayerNameByIdentifier','getPlayerData','getMetadata','getCharInfo','getJob','getJobName','getJobType','getJobDuty','getJobData',
    'getJobGrade','getJobGradeLevel','getJobGradeName','getJobGradePay','isBoss','getGang','getGangName','getGangData','getGangGrade',
    'getGangGradeLevel','getGangGradeName','isLeader','getAllGangs','getEntityCoords','getDistance','checkDistance','getNearbyPlayers',
    'getJobCount','getJobTypeCount','createUseable','setJob','setJobDuty','addMoney','removeMoney','getMoney','getAllJobs','getJobTable',
    'getSharedJob','getSharedJobData','getSharedJobGrade','getSharedJobGradeData','jobExists','vehicleOwner','hasPermission','isOnline',
    'getSharedItems','getItemLabel','getItemWeight','getSharedVehicle','getSharedVehicleData','getSharedWeapons','getSharedWeaponData',
    'getSharedGang','getSharedGangData','getSharedGangRankData',
}) do
    exports(name, ps[name])
end

ps.success('Framework Module Loaded: HPX')

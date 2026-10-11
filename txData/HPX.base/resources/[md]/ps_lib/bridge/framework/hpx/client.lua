-- HPX framework bridge for ps_lib. Added for the HPX framework (modification of ps_lib, CC BY-NC-SA 4.0, see LICENSE.md).
local core = exports.hpx_core

local function data()
    local ok, playerData = pcall(function() return core:GetPlayerData() end)
    return ok and type(playerData) == 'table' and playerData or {}
end

local function job() return type(data().job) == 'table' and data().job or {} end
local function gang() return type(data().gang) == 'table' and data().gang or {} end

function ps.getPlayerData() return data() end
function ps.getIdentifier() return data().citizenid end

function ps.getMetadata(meta)
    local metadata = data().metadata or {}
    if meta then return metadata[meta] end
    return metadata
end

function ps.getCharInfo(info)
    local charinfo = data().charinfo or {}
    if info then return charinfo[info] end
    return charinfo
end

function ps.getPlayerName()
    local info = data().charinfo or {}
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

function ps.getPlayer() return { PlayerData = data() } end

function ps.getVehicleLabel(model)
    if type(model) == 'string' then model = joaat(model) end
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    return label ~= 'NULL' and label or 'Unknown'
end

function ps.isDead()
    local metadata = data().metadata or {}
    return metadata.isdead == true or metadata.inlaststand == true
end

function ps.getJob() return job() end
function ps.getJobName() return job().name end
function ps.getJobType() return job().type end
function ps.isBoss() return job().isboss == true end
function ps.getJobDuty() return job().onduty == true end
function ps.getJobData(key) return job()[key] end
function ps.getGang() return gang() end
function ps.getGangName() return gang().name end
function ps.isLeader() return gang().isboss == true end
function ps.getGangData(key) return gang()[key] end
function ps.getCoords() return GetEntityCoords(PlayerPedId()) end
function ps.getMoneyData() return data().money or {} end
function ps.getMoney(account) return (data().money or {})[account] or 0 end
function ps.getAllMoney() return data().money or {} end

for _, name in ipairs({
    'getPlayerData','getIdentifier','getMetadata','getCharInfo','getPlayerName','getPlayer','getVehicleLabel','isDead','getJob',
    'getJobName','getJobType','isBoss','getJobDuty','getJobData','getGang','getGangName','isLeader','getGangData','getCoords',
    'getMoneyData','getMoney','getAllMoney',
}) do
    exports(name, ps[name])
end

ps.success('Framework Module Loaded: HPX')

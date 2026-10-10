---@type FrameworkInfo Detected framework descriptor (bridge.shared.framework).
local framework = require 'bridge.shared.framework'
---@type table Player resolution helpers (bridge.server.player).
local playerMod = require 'bridge.server.player'

---@type table Money helper module returned to consumers.
local money = {}

---Normalises money type names across frameworks: ESX wants `money` for cash, QBCore wants `cash`;
---both accept `bank` as-is.
---@param t string
---@return string
local function convertType(t)
    if t == 'money' and (framework.name == 'qb' or framework.name == 'hpx') then return 'cash' end
    if t == 'cash' and framework.name == 'esx' then return 'money' end
    return t
end

---Current balance of one account, 0 when the player or framework is missing.
---@param source number
---@param moneyType string 'cash' | 'bank'
---@return number
function money.get(source, moneyType)
    local p = playerMod.get(source)
    if not p then return 0 end
    local t = convertType(moneyType)
    if framework.name == 'hpx' then return framework.core:GetMoney(source, t) or 0 end
    if framework.name == 'qb' then return p.PlayerData.money[t] or 0 end
    if framework.name == 'esx' then
        local account = p.getAccount(t)
        return account and account.money or 0
    end
    return 0
end

---Debit an account. Returns false when the full amount could not be taken (unknown player, no
---framework, insufficient balance), so callers can use it as an affordability gate.
---@param source number
---@param moneyType string 'cash' | 'bank'
---@param amount number
---@param reason string|nil
---@return boolean
function money.remove(source, moneyType, amount, reason)
    if amount <= 0 then return true end
    local p = playerMod.get(source)
    if not p then return false end
    local t = convertType(moneyType)
    if framework.name == 'hpx' then
        return framework.core:RemoveMoney(source, t, amount, reason) and true or false
    end
    if framework.name == 'qb' then
        return p.Functions.RemoveMoney(t, amount, reason) and true or false
    end
    if framework.name == 'esx' then
        local account = p.getAccount(t)
        if not account or (account.money or 0) < amount then return false end
        p.removeAccountMoney(t, amount)
        return true
    end
    return false
end

---Credit an account (refunds). Returns false when the player or framework is missing.
---@param source number
---@param moneyType string 'cash' | 'bank'
---@param amount number
---@param reason string|nil
---@return boolean
function money.add(source, moneyType, amount, reason)
    if amount <= 0 then return true end
    local p = playerMod.get(source)
    if not p then return false end
    local t = convertType(moneyType)
    if framework.name == 'hpx' then
        return framework.core:AddMoney(source, t, amount, reason) and true or false
    end
    if framework.name == 'qb' then
        return p.Functions.AddMoney(t, amount, reason) and true or false
    end
    if framework.name == 'esx' then
        p.addAccountMoney(t, amount)
        return true
    end
    return false
end

return money

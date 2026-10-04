local function getPlayer(source)
    return exports.hpx_core:GetPlayer(source)
end

local function normalizeAmount(amount)
    amount = tonumber(amount)
    if not amount then return nil end
    amount = math.floor(amount * 100) / 100
    if amount <= 0 or amount > HPXBankingConfig.transactionLimit then return nil end
    return amount
end

local function getAccount(source)
    local player = getPlayer(source)
    if not player or not player.charid then return nil end

    local account = MySQL.single.await(
        'SELECT id, balance, account_type FROM hpx_accounts WHERE character_id = ? AND account_type = ? LIMIT 1',
        { player.charid, HPXBankingConfig.defaultAccountType }
    )

    if account then return account end

    local id = MySQL.insert.await(
        'INSERT INTO hpx_accounts (character_id, account_type, balance) VALUES (?, ?, 0)',
        { player.charid, HPXBankingConfig.defaultAccountType }
    )

    return {
        id = id,
        balance = 0,
        account_type = HPXBankingConfig.defaultAccountType
    }
end

lib.callback.register('hpx:banking:getAccount', function(source)
    local account = getAccount(source)
    if not account then return nil end
    return {
        id = account.id,
        balance = account.balance,
        accountType = account.account_type
    }
end)

lib.callback.register('hpx:banking:deposit', function(source, amount)
    amount = normalizeAmount(amount)
    if not amount then return false, 'invalid_amount' end

    local player = getPlayer(source)
    local account = getAccount(source)
    if not player or not account then return false, 'no_account' end

    local removed = player:RemoveMoney('cash', amount, 'bank-deposit')
    if not removed then return false, 'insufficient_cash' end

    MySQL.update.await('UPDATE hpx_accounts SET balance = balance + ? WHERE id = ?', { amount, account.id })
    return true
end)

lib.callback.register('hpx:banking:withdraw', function(source, amount)
    amount = normalizeAmount(amount)
    if not amount then return false, 'invalid_amount' end

    local account = getAccount(source)
    if not account or tonumber(account.balance) < amount then
        return false, 'insufficient_funds'
    end

    local changed = MySQL.update.await(
        'UPDATE hpx_accounts SET balance = balance - ? WHERE id = ? AND balance >= ?',
        { amount, account.id, amount }
    )

    if changed ~= 1 then return false, 'insufficient_funds' end

    local player = getPlayer(source)
    if not player then return false, 'no_player' end

    player:AddMoney('cash', amount, 'bank-withdraw')
    return true
end)

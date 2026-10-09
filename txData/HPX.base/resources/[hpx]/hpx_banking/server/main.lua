-- ATM DUI system by OsmFX Mods (https://osmfxmods.com) - https://github.com/OsmFX-Mods/osm-atmdui
-- Used with the author's permission and adapted for hpx_core. Original license: LICENSE-osm-atmdui.txt
--
-- Server logic: PIN, card, withdraw, deposit, transfer and receipts.
-- Money moves through the framework bridge (cash and bank of hpx_core).

local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

ATM_Server = {}

local lastAction = { money = {}, receipt = {} }
local pinState = {}

local RECEIPT_TYPES <const> = { withdraw = true, deposit = true, transfer = true, unknown = true }

local function throttled(source, bucket)
    local now = GetGameTimer()
    local last = lastAction[bucket or 'money']
    if (last[source] or 0) + Config.Security.actionCooldown > now then return true end
    last[source] = now
    return false
end

AddEventHandler('playerDropped', function()
    lastAction.money[source] = nil
    lastAction.receipt[source] = nil
    pinState[source] = nil
end)

local function normalizeAmount(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    value = math.floor(value * 100 + 0.5) / 100
    if value <= 0 then return nil end
    return value
end

local function feeFor(amount)
    return Config.Transactions.fee + (amount * (Config.Transactions.feePercent / 100))
end

local function formatMoney(amount)
    if math.floor(amount) == amount then return ('$%d'):format(amount) end
    return ('$%.2f'):format(amount)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS hpx_bank_transactions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(32) NOT NULL,
            type VARCHAR(16) NOT NULL,
            amount DECIMAL(15,2) NOT NULL,
            fee DECIMAL(15,2) NOT NULL DEFAULT 0,
            target VARCHAR(64) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_hpx_bank_tx_citizen (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end)

-- Wait for bridge to be ready
CreateThread(function()
    while not Bridge.Ready do
        Wait(100)
    end

    Wait(500)
    print('^2[atm-dui] Server initialized!^0')

    ATM_Server.RegisterCallbacks()
end)

-- Log transaction to the database
function ATM_Server.LogTransaction(source, transType, amount, fee, targetAccount)
    local identifier = Bridge.GetPlayerIdentifier(source)
    if not identifier then return end

    MySQL.insert(
        'INSERT INTO hpx_bank_transactions (citizenid, type, amount, fee, target) VALUES (?, ?, ?, ?, ?)',
        { identifier, transType, amount, fee, targetAccount and tostring(targetAccount):sub(1, 64) or nil }
    )

    print(string.format('^3[atm-dui] Transaction: %s | Type: %s | Amount: %s | Fee: %s^0',
        identifier, transType, formatMoney(amount), formatMoney(fee)))
end

-- Register all callbacks
function ATM_Server.RegisterCallbacks()
    -- Verify PIN
    lib.callback.register('atm-dui:server:verifyPIN', function(source, enteredPIN)
        local src = source

        local state = pinState[src]
        if state and state.lockedUntil and state.lockedUntil > os.time() then
            return false
        end

        local valid
        if Config.PIN.requireCard then
            local cardData = Bridge.GetItemData(src, 'bank_card')
            valid = cardData ~= nil and cardData.cardPin ~= nil and tostring(cardData.cardPin) == tostring(enteredPIN)
        else
            valid = #tostring(enteredPIN) == Config.PIN.length
        end

        if valid then
            pinState[src] = nil
            return true
        end

        state = state or { failures = 0 }
        state.failures = state.failures + 1
        if state.failures >= Config.PIN.maxAttempts then
            state.failures = 0
            state.lockedUntil = os.time() + Config.PIN.lockoutTime
        end
        pinState[src] = state

        return false
    end)

    -- Create Card
    lib.callback.register('atm-dui:server:createCard', function(source, pin)
        local src = source
        if not Config.PIN.allowCardCreation or throttled(src) then return false end

        pin = tostring(pin or '')
        if #pin ~= Config.PIN.length or not pin:match('^%d+$') then return false end

        local cost = Config.PIN.cardCreationCost or 50

        local paidFrom
        if Bridge.GetPlayerMoney(src, 'bank') >= cost and Bridge.RemoveMoney(src, 'bank', cost, 'ATM Card Issue') then
            paidFrom = 'bank'
        elseif Bridge.GetPlayerMoney(src, 'cash') >= cost and Bridge.RemoveMoney(src, 'cash', cost, 'ATM Card Issue') then
            paidFrom = 'cash'
        end

        if not paidFrom then
            return false
        end

        local cardNumber = string.format('%04d %04d %04d %04d', math.random(1000, 9999), math.random(1000, 9999), math.random(1000, 9999), math.random(1000, 9999))

        local metadata = {
            cardPin = pin,
            cardNumber = cardNumber,
            citizenid = Bridge.GetPlayerIdentifier(src),
            name = Bridge.GetPlayerName(src),
            expiry = os.date('%m/%y', os.time() + (365 * 24 * 60 * 60 * 3))
        }

        if not Bridge.AddItem(src, 'bank_card', 1, metadata) then
            Bridge.AddMoney(src, paidFrom, cost, 'ATM Card Issue refund')
            return false
        end

        return true
    end)

    -- Withdraw money
    lib.callback.register('atm-dui:server:withdraw', function(source, amount)
        local src = source
        local bank = Bridge.GetPlayerMoney(src, 'bank')

        if throttled(src) then return false, bank, 'Please wait' end

        amount = normalizeAmount(amount)
        if not amount then return false, bank, 'Invalid amount' end
        if amount > Config.Transactions.maxWithdraw then return false, bank, 'Amount exceeds limit' end

        local fee = feeFor(amount)
        local total = amount + fee
        if bank < total then
            return false, bank, fee > 0 and 'Insufficient funds (including fee)' or 'Insufficient funds'
        end

        if not Bridge.RemoveMoney(src, 'bank', total, 'ATM Withdrawal') then
            return false, bank, 'Transaction failed'
        end

        if not Bridge.AddMoney(src, 'cash', amount, 'ATM Withdrawal') then
            Bridge.AddMoney(src, 'bank', total, 'ATM Withdrawal refund')
            return false, Bridge.GetPlayerMoney(src, 'bank'), 'Transaction failed'
        end

        ATM_Server.LogTransaction(src, 'withdraw', amount, fee)

        return true, Bridge.GetPlayerMoney(src, 'bank'), nil
    end)

    -- Deposit money
    lib.callback.register('atm-dui:server:deposit', function(source, amount)
        local src = source
        local bank = Bridge.GetPlayerMoney(src, 'bank')

        if throttled(src) then return false, bank, 'Please wait' end

        amount = normalizeAmount(amount)
        if not amount then return false, bank, 'Invalid amount' end
        if amount > Config.Transactions.maxDeposit then return false, bank, 'Amount exceeds limit' end

        if Bridge.GetPlayerMoney(src, 'cash') < amount then
            return false, bank, 'Insufficient cash'
        end

        if not Bridge.RemoveMoney(src, 'cash', amount, 'ATM Deposit') then
            return false, bank, 'Transaction failed'
        end

        if not Bridge.AddMoney(src, 'bank', amount, 'ATM Deposit') then
            Bridge.AddMoney(src, 'cash', amount, 'ATM Deposit refund')
            return false, Bridge.GetPlayerMoney(src, 'bank'), 'Transaction failed'
        end

        ATM_Server.LogTransaction(src, 'deposit', amount, 0)

        return true, Bridge.GetPlayerMoney(src, 'bank'), nil
    end)

    -- Transfer money
    lib.callback.register('atm-dui:server:transfer', function(source, targetIdentifier, amount)
        local src = source
        local bank = Bridge.GetPlayerMoney(src, 'bank')

        if throttled(src) then return false, bank, 'Please wait' end

        amount = normalizeAmount(amount)
        if not amount then return false, bank, 'Invalid amount' end
        if amount > Config.Transactions.maxTransfer then return false, bank, 'Amount exceeds limit' end

        targetIdentifier = tostring(targetIdentifier or '')
        if #targetIdentifier < 1 or #targetIdentifier > 32 or not targetIdentifier:match('^[%w%-]+$') then
            return false, bank, 'Invalid account number'
        end

        local myIdentifier = Bridge.GetPlayerIdentifier(src)
        if not myIdentifier then return false, bank, 'Transaction failed' end
        if myIdentifier == targetIdentifier then
            return false, bank, 'Cannot transfer to yourself'
        end

        local fee = feeFor(amount)
        local total = amount + fee
        if bank < total then return false, bank, 'Insufficient funds' end

        -- Find the target: online players first, then stored characters
        local target = Bridge.GetPlayerByIdentifier(targetIdentifier)
        local offline = false
        if not target then
            if not Bridge.CreditOffline or (Bridge.AccountExists and not Bridge.AccountExists(targetIdentifier)) then
                return false, bank, 'Account not found'
            end
            offline = true
        end

        if not Bridge.RemoveMoney(src, 'bank', total, 'ATM Transfer to ' .. targetIdentifier) then
            return false, bank, 'Transaction failed'
        end

        local credited
        if offline then
            credited = Bridge.CreditOffline(targetIdentifier, amount)
        else
            credited = Bridge.AddMoney(target.source, 'bank', amount, 'ATM Transfer from ' .. myIdentifier)
        end

        if not credited then
            Bridge.AddMoney(src, 'bank', total, 'ATM Transfer refund')
            return false, Bridge.GetPlayerMoney(src, 'bank'), 'Account not found'
        end

        if not offline then
            Bridge.Notify(target.source, 'You received ' .. formatMoney(amount) .. ' from a transfer', 'success')
        end

        ATM_Server.LogTransaction(src, 'transfer', amount, fee, targetIdentifier)

        return true, Bridge.GetPlayerMoney(src, 'bank'), nil
    end)

    -- Get balance
    lib.callback.register('atm-dui:server:getBalance', function(source)
        local src = source
        return {
            bank = Bridge.GetPlayerMoney(src, 'bank'),
            cash = Bridge.GetPlayerMoney(src, 'cash')
        }
    end)

    -- Get player data for ATM
    lib.callback.register('atm-dui:server:getPlayerData', function(source)
        local src = source
        return {
            name = Bridge.GetPlayerName(src),
            identifier = Bridge.GetPlayerIdentifier(src),
            bank = Bridge.GetPlayerMoney(src, 'bank'),
            cash = Bridge.GetPlayerMoney(src, 'cash')
        }
    end)
end

-- Receipts
RegisterNetEvent('atm-dui:server:createReceipt', function(info)
    local src = source
    if not src or src <= 0 or type(info) ~= 'table' or not Bridge.Ready or throttled(src, 'receipt') then return end
    if not Bridge.GetPlayerIdentifier(src) then return end

    local transactionType = tostring(info.type or 'unknown')
    if not RECEIPT_TYPES[transactionType] then transactionType = 'unknown' end

    Bridge.AddItem(src, 'atm_receipt', 1, {
        type = transactionType,
        amount = normalizeAmount(info.amount) or 0,
        account = tostring(info.account or 'N/A'):sub(1, 64),
        balance = Bridge.GetPlayerMoney(src, 'bank'),
        date = os.date('%Y-%m-%d %H:%M:%S')
    })
end)

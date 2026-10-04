local active = nil

local function close()
    if not active then return end
    exports.hpx_dui:Destroy(active)
    active = nil
end

local function openBank()
    if active then return end

    local account = lib.callback.await('hpx:banking:getAccount', false)
    if not account then return end

    local surface = exports.hpx_dui:Create({
        width = HPXBankingConfig.dui.width,
        height = HPXBankingConfig.dui.height
    })

    if not surface then return end

    active = surface.id

    exports.hpx_dui:Send(active, {
        action = 'render',
        html = string.format(
            '<div style="height:100%%;background:#101216;color:white;padding:40px"><h1>HPX BANK</h1><h2>%s%.2f</h2><p>Checking account</p></div>',
            HPXBankingConfig.currency,
            tonumber(account.balance) or 0
        )
    })
end

RegisterCommand('hpxbank', openBank, false)

exports('Open', openBank)
exports('Close', close)

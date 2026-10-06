local registered = false

local atmModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}

CreateThread(function()
    exports.hpx_core:AddModelInteraction({
        models = atmModels,
        name = 'hpx_atm',
        distance = 1.6,
        options = {
            {
                label = 'Use ATM',
                icon = 'credit-card',
                action = function()
                    exports.hpx_banking:Open()
                end
            }
        }
    })

    registered = true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not registered then return end
    exports.hpx_core:RemoveModelInteraction('hpx_atm')
end)

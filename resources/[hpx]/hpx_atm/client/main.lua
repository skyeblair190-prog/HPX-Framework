local registered = {}

local atmModels = {
    `prop_atm_01`,
    `prop_atm_02`,
    `prop_atm_03`,
    `prop_fleeca_atm`
}

CreateThread(function()
    while not exports.hpx_interact do
        Wait(500)
    end

    exports.hpx_interact:AddModelInteraction({
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
    if exports.hpx_interact.RemoveModelInteraction then
        exports.hpx_interact:RemoveModelInteraction('hpx_atm')
    end
end)

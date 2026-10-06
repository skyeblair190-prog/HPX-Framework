HPXBankingConfig = {
    defaultAccountType = 'checking',
    currency = '$',
    transactionLimit = 1000000,
    fee = 0,
    dui = {
        width = 1024,
        height = 768
    },
    atm = {
        interactDistance = 1.6,
        quickAmounts = { 20, 50, 100, 200, 500, 1000 },

        -- Screen texture replaced by the DUI on every ATM prop: texture dictionary (the model name) and texture name.
        textures = {
            prop_atm_01 = { dict = 'prop_atm_01', name = 'prop_cashpoint_screen' },
            prop_atm_02 = { dict = 'prop_atm_02', name = 'prop_cashpoint_screen' },
            prop_atm_03 = { dict = 'prop_atm_03', name = 'prop_cashpoint_screen' },
            prop_fleeca_atm = { dict = 'prop_fleeca_atm', name = 'prop_fleece_emis' }
        },

        -- Scripted camera used while a player is at an ATM; per model overrides go in models.
        camera = {
            enabled = true,
            default = { distance = 0.7, height = 1.4, lookHeight = 1.1, side = 0.0, fov = 45.0 },
            models = {}
        }
    }
}

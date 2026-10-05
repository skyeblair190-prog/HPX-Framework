Config = {}

Config.Framework = 'auto' -- auto | hpx | qb | esx | qbx
Config.Inventory = 'auto' -- auto | ox | qb | esx

Config.Debug = false

Config.Hints = {
    move = 'MOVE',
    select = 'SELECT',
    back = 'BACK',
}

Config.Target = {
    system = 'auto', -- auto | ox | qb | text (E prompt, used when no target resource is started)
    label = 'Talk',
    icon = 'fas fa-comments',
    distance = 2.5,
}

Config.Peds = {
    {
        id = 'fleet_clerk',
        model = 'cs_lifeinvad_01',
        coords = vector4(235.0011, -883.8326, 29.4916, 325.9854),
        anim = { dict = 'amb@world_human_clipboard@male@base', name = 'base', flag = 1 },
        scene = {
            dict = 'missfbi3_party_d',
            ped = 'stand_talk_loop_a_male1',
            player = 'stand_talk_loop_a_male1',
        },
        target = {
            label = 'Talk',
            icon = 'fas fa-comments',
            distance = 2.5,
        },
        dialog = {
            name = 'FLEET CLERK',
            role = 'Lifeinvader NEWS',
            text = 'Hey. Shop is open if you need kit, or I can pull a fleet unit for you.',
            -- client = 'clientEvent'   visual only
            -- server = 'serverEvent'   cash and items live in that handler
            -- fn = function(src, pedId, optionId, result) end
            -- next = 'nodeId'   back = true   keepOpen = true
            options = {
                { id = 'shop', label = 'SHOP' },
                { id = 'paper', label = 'BUY PAPER', keepOpen = true, server = 'hasib_peddialog:fleet:paper' },
                { id = 'garage', label = 'GARAGE', next = 'garage' },
            },
        },
        shop = {
            moneyType = 'cash',
            label = 'Lifeinvader NEWS',
            address = { 'LEGION SQUARE', 'LOS SANTOS' },
            tax = 0,
            items = {
                { item = 'newskit', label = 'NEWS KIT', price = 250, category = 'tools' },
                { item = 'laptopnews', label = 'NEWS LAPTOP', price = 500, category = 'tools' },
                { item = 'paper', label = 'PAPER', price = 2, category = 'tools' },
                { item = 'printer', label = 'PRINTER', price = 750, category = 'tools' },
            },
        },
        nodes = {
            garage = {
                role = 'GARAGE',
                text = 'Alright — which unit do you want out front?',
                options = {
                    { id = 'rumpo', label = 'RUMPO' },
                    { id = 'back', label = 'GO BACK', back = true },
                },
            },
        },
    },
}

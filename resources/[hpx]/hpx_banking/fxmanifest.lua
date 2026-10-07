fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'hpx_banking'
description 'Banking and ATM DUI system for HPX. ATM DUI by OsmFX Mods (osmfxmods.com), used with the author permission'
author 'osmfxmods.com (ATM DUI), HPX'
version '1.0.0'

dependencies {
    'hpx_core',
    'hpx_notify',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/bridge.lua',
    'bridge/client/*.lua',
    'client/dui.lua',
    'client/camera.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'bridge/server/*.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/*.ogg',
}

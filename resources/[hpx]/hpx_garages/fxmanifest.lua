fx_version 'cerulean'
game 'gta5'

name 'hpx_garages'
description 'Garage system for HPX, ported from qbx_garages'
repository 'https://github.com/Qbox-project/qbx_garages'
version '1.1.4'

ox_lib 'locale'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/default-calculate-impound-fee.lua',
    'server/main.lua',
    'server/spawn-vehicle.lua',
}

files {
    'config/client.lua',
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

dependencies { 'hpx_core', 'hpx_vehicles', 'hpx_notify', 'ox_lib', 'oxmysql' }

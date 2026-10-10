fx_version 'cerulean'
game 'gta5'

description 'Codera-RadialMenu'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/locale.lua',
    'locales/en.lua' -- Change this to your preferred language
}

client_scripts {
    'client/qb.lua',
    'client/main.lua',
    'client/blips.lua',
    'client/clothing.lua',
    'client/extraevents.lua',
    'client/stretcher.lua',
    'client/trunk.lua'
}

server_scripts {
    'server/qb.lua',
    'server/stretcher.lua',
    'server/trunk.lua'
}

dependencies {
    'ox_lib',
    'hpx_core',
    'hpx_notify'
}

files {
    'html/index.html',
    'html/css/main.css',
    'html/fonts/*.woff2',
    'html/img/*.png',
    'html/js/main.js',
    'html/js/RadialMenu.js',
}

lua54 'yes'


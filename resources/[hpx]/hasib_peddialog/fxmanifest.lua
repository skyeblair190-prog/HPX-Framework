fx_version 'cerulean'
games { 'gta5' }

author 'mfhasib'
description 'tebex.haaasib.dev'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/dialog.lua',
    'client/ped.lua',
}

server_scripts {
    'server/shop.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/shop.css',
    'html/script.js',
    'html/shop.js',
    'html/img/*.png',
}

ui_page 'html/index.html'

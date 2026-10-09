fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'codera'
description 'Codera HUD '
version '1.3.0'

ui_page 'web/index.html'

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
    'client/settings.lua',
    'client/player.lua',
    'client/vehicle.lua',
    'client/minimap.lua',
    'client/chat.lua'
}

server_scripts {
    'server/main.lua',
    'server/chat.lua'
}

files {
    'web/index.html',
    'web/css/*.css',
    'web/fonts/*.woff2',
    'web/js/*.js'
}

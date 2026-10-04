fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua'
}

client_script 'client/main.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/fonts/*.woff2'
}

dependencies { 'hpx_core', 'hpx_vehicles', 'ox_lib', 'oxmysql' }

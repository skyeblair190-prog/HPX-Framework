fx_version 'cerulean'
game 'gta5'
lua54 'yes'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/script.js',
  'web/fonts/*.woff2'
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua'
}

client_scripts {
  'client/main.lua',
  'client/atm.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

dependencies {
  'hpx_core',
  'hpx_dui',
  'interact',
  'ox_lib',
  'oxmysql'
}

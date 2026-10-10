fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'HPX Tablet (Codera tablet UI)'

ui_page 'codera-web/index.html'

files {
  'codera-web/**'
}

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

client_scripts {
  'client/core.lua',
  'client/main.lua',
  'client/open.lua'
}

server_script 'server/main.lua'

dependencies { 'ox_lib', 'hpx_core', 'hpx_notify', 'ox_inventory' }

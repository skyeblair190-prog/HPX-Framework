fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'HPX Dispatch (Codera dispatch UI)'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
  'html/**'
}

dependencies { 'ox_lib', 'hpx_core', 'hpx_notify' }

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

dependencies { 'hpx_core', 'ox_lib', 'oxmysql' }

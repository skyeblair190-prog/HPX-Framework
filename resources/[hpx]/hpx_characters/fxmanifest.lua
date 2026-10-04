fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script '@ox_lib/init.lua'

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

dependencies { 'hpx_core', 'ox_lib' }

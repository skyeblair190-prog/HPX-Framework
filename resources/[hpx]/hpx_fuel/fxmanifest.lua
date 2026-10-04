fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script '@ox_lib/init.lua'
client_scripts { 'shared/config.lua', 'client/main.lua' }
server_script 'server/main.lua'

dependencies { 'hpx_core', 'hpx_dui', 'hpx_interact', 'ox_lib' }

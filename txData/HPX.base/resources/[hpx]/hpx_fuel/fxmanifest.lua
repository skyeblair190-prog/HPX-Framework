fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies { 'hpx_core', 'hpx_dui', 'interact', 'ox_lib' }

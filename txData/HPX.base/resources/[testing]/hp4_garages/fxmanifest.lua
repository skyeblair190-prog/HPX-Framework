fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hp4_garages'
description 'Persistent SQL vehicle garages with collision-safe parking spots'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_scripts { 'client/main.lua', 'client/admin.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/db.lua', 'server/main.lua', 'server/admin.lua' }

files { 'web/index.html', 'sql/*.sql' }

dependencies { 'ox_lib', 'oxmysql' }

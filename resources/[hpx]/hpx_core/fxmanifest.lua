fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/constants.lua',
  'shared/utils.lua',
  'shared/validators.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/cache.lua',
  'server/identifiers.lua',
  'server/database.lua',
  'server/state.lua',
  'server/generator.lua',
  'server/permissions.lua',
  'server/player.lua',
  'server/character.lua',
  'server/money.lua',
  'server/callbacks.lua',
  'server/events.lua',
  'server/main.lua',
  'server/exports.lua'
}

dependencies {
  'ox_lib',
  'oxmysql'
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'HPX Payphone (Codera payphone UI)'

shared_script 'config.lua'
client_script 'client.lua'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/asset-manifest.json',
  'web/static/media/*.ttf',
  'web/static/media/*.otf',
  'web/static/js/*.js',
  'web/static/css/*.css'
}

dependencies { 'interact', 'hpx_notify' }

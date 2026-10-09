fx_version 'cerulean'
game 'gta5'

name 'codera-vcontrol'
author 'Codera Development'
description ' Vehicle Control Menu V'
version '1.0.0'

ui_page 'html/s7vrkpcz.html'

files {
    'html/s7vrkpcz.html',
    'html/f2b0g9um.css',
    'html/img/*.png',
    'html/*.woff2'
}

client_scripts {
    'config.lua',
    'client.lua'
}

exports {
    'openVehControl',
    'openExternal',
    'openMenu',
    'closeVehControl',
    'closeMenu',
    'toggleMenu'
}


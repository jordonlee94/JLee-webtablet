fx_version 'cerulean'
game 'gta5'

name 'qb-darkwebtablet'
author 'JLee'
description 'Dark Web Tablet Marketplace for QBCore'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/logo.png'
}

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

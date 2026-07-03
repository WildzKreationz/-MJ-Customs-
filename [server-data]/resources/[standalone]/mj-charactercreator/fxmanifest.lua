fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'MJ Customs'
description 'Standalone FiveM freemode character creator and clothing preview tool'
version '1.0.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_scripts {
    'client/utils.lua',
    'client/clothing.lua',
    'client/camera.lua',
    'client/main.lua'
}

server_script 'server/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

fx_version 'cerulean'
game 'gta5'

author 'ChatGPT (generated)'
description 'Bridgeport Chicago neighborhood resource - teleports, dynamic NPCs, day/night behavior, robbery proxies'
version '1.2.0'

client_script 'client.lua'
server_script 'server.lua'

shared_script 'locations.lua'
shared_script 'config.lua'

files {
    'stream/bridgeport_draft.ymap'
}

data_file 'DLC_ITYP_REQUEST' 'stream/bridgeport_draft.ymap'

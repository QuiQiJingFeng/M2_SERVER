local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local pbc = require "protobuf"
local redis = require "skynet.db.redis"
local cjson = require "cjson"
require "skynet.manager"



local CMD = {}

function CMD.startGame(game_type,room_info)
	local game = require(game_type..".".."game.lua")
	--初始化
	game:init(room_info)
	game:start()
end

function CMD.gameCMD(command,user_id,info)
	game:gameCMD(command,user_id,info)
end

function CMD.clean()

end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    skynet.register ".game"
end)

local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"

local CMD = {}
local GAME = nil

function CMD.startGame(room_info)
	local game_type = room_info.game_type
	GAME = require(game_type..".".."game.lua")
	--初始化
	GAME:start(room_info)
end

function CMD.gameCMD(data)
	return GAME:gameCMD(data)
end

function CMD.clear()
	GAME = nil
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    skynet.register ".game"
end)

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log = require "skynet.log"
require "skynet.manager"
local constant = require "constant"
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local CMD = {}
local game

function CMD.startGame(room_info)
	print("FYD++++++START GAME")
	local game_type = RECOVER_GAME_TYPE[room_info.game_type]
	game = require(string.lower(game_type)..".".."game")
	--初始化
	game:init(room_info)
	game:start()
end

function CMD.gameCMD(data)
	return game:gameCMD(data)
end

--当房间被销毁的时候,需要清理游戏的数据
function CMD.clear()
	if game then
		game:clear()
	end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    skynet.register ".game"
end)

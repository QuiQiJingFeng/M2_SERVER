local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log = require "skynet.log"
require "skynet.manager"
local constant = require "constant"
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local CMD = {}
local game

function CMD.startGame(room_id,game_type)
	local gtype = RECOVER_GAME_TYPE[game_type]
	game = require(string.lower(gtype)..".".."game")
	--初始化
	game:init(room_id,gtype)
	game:start()
end

function CMD.gameCMD(data)
	if game then
		return game:gameCMD(data)
	else
		local cjson = require "cjson"
		print("ERROR:====>>>>>",cjson.encode(data))
	end
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

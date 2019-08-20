local Room = require "Room"
local config_manager = require "config_manager"
local utils = require "utils"
local CARD_TYPE = config_manager.constant.CARD_TYPE
local Card = require "Card"
--开局前命令 很多玩法开局的时候都会有特殊的操作,对于这种可以重写这个命令
--比如下跑、叫分、亮四打一
local CommandPreStart = class("CommandPreStart")

function CommandPreStart:ctor()

end

function CommandPreStart:execute()
	CommandCenter:getInstance():executeCommand("CommandStart")
end

return CommandPreStart
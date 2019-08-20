local constant = config_manager.constant
local PLAY_TYPE = constant.PLAY_TYPE

local commanCommands = {
	[PLAY_TYPE.COMMAND_PRE_START] = require("gameplays.GAME_TYPE_COMMON.CommandPreStart.lua"),
	--牌局开始
	[PLAY_TYPE.COMMAND_START] = require("gameplays.GAME_TYPE_COMMON.CommandStart.lua"),
	--打牌
	[PLAY_TYPE.COMMAND_PLAY_CARD] = require("gameplays.GAME_TYPE_COMMON.CommandPlayCard"),
}

return commanCommands
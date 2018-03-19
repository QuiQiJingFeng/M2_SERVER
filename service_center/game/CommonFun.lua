local CommonFun = {}

local cluster = require "skynet.cluster"
local CONSTANT = require("constant")


-- 准备事件
function CommonFun:callBackReady( ... )
	-- body
end

-- 玩家出牌
function CommonFun:handleSendCardsReq( ... )
	-- body
end


function CommonFun:onGameEnd( ... )
	-- body
end



return  CommonFun
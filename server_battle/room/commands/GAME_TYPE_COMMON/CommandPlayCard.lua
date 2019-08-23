local Room = require "Room"
local PLAY_TYPE = config_manager.constant.PLAY_TYPE
local CommandPlayCard = class("CommandPlayCard")

function CommandPlayCard:execute(content)
	local roleId = content.roleId
	local cardId = content.cardId
	local place = Room:getInstance():getPlaceByRoleId(roleId)
	local card = place:removeHandCardById(cardId)
	place:addOutCard(card)

	--检测其他位置有没有吃碰杠胡
	local num = Room:getInstance():getPlayerNum()
	local rolePos = place:getPosition()
	for pos=1,num do
		if pos ~= rolePos then
			local place = Room:getInstance():getPlace(pos)
			if place:isChi(card) then
				local roleId = place:getRoleId()
				local playType,stepInfo = Room:getInstance():waiteActive(roleId)
				if playType == PLAY_TYPE.COMMAND_CHI then
					CommandCenter:getInstance():execute(playType,stepInfo)
					return
				end
			elseif place:isGang(card) then
				local roleId = place:getRoleId()
				--NOTICE ROLEID PENG/GUO
				local playType,stepInfo = Room:getInstance():waiteActive(roleId)
				if playType == PLAY_TYPE.COMMAND_PENG then
					CommandCenter:getInstance():execute(playType,stepInfo)
					return
				elseif playType == PLAY_TYPE.COMMAND_GANG_A_CARD then
					CommandCenter:getInstance():execute(playType,stepInfo)
					return
				end
			elseif place:isPeng(card) then
				local roleId = place:getRoleId()
				--NOTICE ROLEID PENG/GUO
				local playType = Room:getInstance():waiteActive(roleId)
				if playType == PLAY_TYPE.COMMAND_PENG then
					CommandCenter:getInstance():execute(playType,stepInfo)
					return
				end
			elseif place:isHu(card) then
				local roleId = place:getRoleId()
				--NOTICE ROLEID PENG/GUO
				local playType = Room:getInstance():waiteActive(roleId)
				if playType == PLAY_TYPE.COMMAND_HU then
					CommandCenter:getInstance():execute(playType,stepInfo)
					return
				end
			end
		end
	end
 
end




return CommandPlayCard
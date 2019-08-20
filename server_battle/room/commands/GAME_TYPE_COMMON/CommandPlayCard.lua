local Room = require "Room"
local CommandPlayCard = class("CommandPlayCard")

function CommandPlayCard:execute(content)
	local roleId = content.roleId
	local cardId = content.cardId
	local place = Room:getInstance():getPlaceByRoleId()
	local card = place:removeHandCardById(cardId)
	--检测其他位置有没有吃碰杠胡
	place:addOutCard(card)


end

return CommandPlayCard
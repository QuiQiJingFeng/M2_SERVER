local Room = require "Room"
local config_manager = require "config_manager"
local utils = require "utils"
local CARD_TYPE = config_manager.constant.CARD_TYPE
local CLIENT_PLAY_TYPE = config_manager.constant.CLIENT_PLAY_TYPE
local Card = require "Card"

local CommandStart = class("CommandStart")

function CommandStart:ctor()

end

function CommandStart:execute()
	self:buildPool()
	self:updateCurRound()
	self:updateZpos()
	self:dealCards()
	-->steps 通知客户端 当前回合、庄家位置、手牌,以及通知庄家出牌
end

--发牌
function CommandStart:dealCards()
	local zpos = Room:getInstance():getZpos()
	local dealNum = 13
	local pool = Room:getInstance():getCardPool()
	for i=1,dealNum do
		local playerNum = Room:getInstance():getPlayerNum()
		for index=1,playerNum do
			local pos = zpos + index - 1
			if pos > playerNum then
				pos = 1
			end
			local place = Room:getInstance():getPlace(pos)
			local card = table.remove(pool)
			place:addHandCard(card)
		end
	end
	local zPlace = Room:getInstance():getPlace(zpos)
	local card = table.remove(pool)
	zPlace:addHandCard(card)
end

--更新庄家的位置
function CommandStart:updateZpos()
	local zpos = Room:getInstance():getZpos()
	zpos = zpos + 1
	if zpos > Room:getInstance():getPlayerNum() then
		zpos = 1
	end
	Room:getInstance():setZpos(zpos)
end

--更新回合数
function CommandStart:updateCurRound()
	Room:getInstance():upgradeCurRound()
	local curRound = Room:getInstance():getCurRound()
	local totalRound = Room:getInstance:getRoundCount()
	assert(curRound <= totalRound,"invilide curRound")
end

--生成牌库
function CommandStart:buildPool()
	--生成牌库的牌
	local pool = {}
	local index = 1
	for value,_ in pairs(CARD_TYPE) do
		if value <= 40 then
			for i=1,4 do
				local card = Card.new(index,value)
				table.insert(self._pool,card)
				index = index + 1
			end
		else
			--不包含花牌
		end
	end
	--洗牌
	utils:fisherYates(pool)
	--设置牌库
	Room:getInstance():setCardPool(pool)
end

return CommandStart
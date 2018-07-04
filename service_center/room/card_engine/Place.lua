local constant = require "card_engine.constant"

local Place = {}

Place.__index = Place

function Place.new()
	local player = {}
	setmetatable(player, Place)
	player.__index = Place
	player:init()

	return player
end

function Place:init()
	self.__totalHuNum = 0
	self.__totalMingGangNum = 0
	self.__totalAnGangNum = 0
	self.__totalScore = 0

	self:clear()
end

function Place:setTotalScore(score)
	self.__totalScore = score
end

function Place:clear()
	--当前局吃碰杠的牌列表
	self.__cardStack = {}
	--已经出的牌列表
	self.__putCardList = {}
	--一些需要额外放置的牌(例如补花，飘)
	self.__markCardList = {}

	--当前的手牌列表
	self.__handleCardList = {}
	--结构化手牌
	self.__handleCardBuild = {}
	-- 最近一次的积分变化
	self.__deltScore = 0
	-- 本局赢的积分
	self.__curScore = 0
	-- 额外的积分,胡牌的时候需要加上
	self.__extraScore = 0
	for type =1,5 do
		for value=1,10 do
			if not self.__handleCardBuild[type] then
				self.__handleCardBuild[type] = {}
			end
			self.__handleCardBuild[type][value] = 0
		end
	end

	-- 最后一张摸到的牌
	self.__lastCard = nil
	-- 记录一些不同麻将所用到的一些数据
	self.__recordData = {}
	self.__tingCard = nil
end

function Place:setTing(card)
	self.__tingCard = card
end

function Place:getTing()
	return self.__tingCard
end

function Place:addExtraScore(deltScore)
	self.__extraScore = self.__extraScore + deltScore
end

function Place:getExtraScore()
	return self.__extraScore
end

function Place:getDeltScore()
	return self.__deltScore
end

-- 记录牌局开始前的积分,某些荒庄要重置掉杠分需要用到
function Place:recordOriginScore()
	self.__originCurScore = self.__curScore
	self.__originTotalScore = self.__totalScore
end

-- 重置积分
function Place:resetOriginScore()
	self.__curScore = self.__originCurScore
	self.__totalScore = self.__originTotalScore
end
 
function Place:updateScore(deltScore)
	self.__deltScore = deltScore
	self.__curScore = self.__curScore + deltScore
	self.__totalScore = self.__totalScore + deltScore
end

function Place:caculateTypeAndValue(card)
	local cardType = math.floor(card / 10) + 1
	local cardValue = card % 10
	return cardType,cardValue
end

function Place:addCard(card)
	self.__lastCard = card
	table.insert(self.__handleCardList,card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	self.__handleCardBuild[cardType][10] = self.__handleCardBuild[cardType][10] + 1
	self.__handleCardBuild[cardType][cardValue] = self.__handleCardBuild[cardType][cardValue] + 1
end
-- skipRecord 是为了构造数据用的,并不是真正的移除牌,后面会补上的
-- 时候用到
function Place:removeCard(card,num,antingCard,skipRecord,mark)
	num = num or 1
	local indexs = {}
	for i=#self.__handleCardList,1,-1 do
		local value = self.__handleCardList[i]
		if value == card then
			table.insert(indexs,i)
		end
	end

	if #indexs < num then
		return false
	end

	for i,idx in ipairs(indexs) do
		if i <= num then
			table.remove(self.__handleCardList,idx)
			local cardType,cardValue = self:caculateTypeAndValue(card)

			self.__handleCardBuild[cardType][10] = self.__handleCardBuild[cardType][10] - 1
			self.__handleCardBuild[cardType][cardValue] = self.__handleCardBuild[cardType][cardValue] - 1
		else
			break
		end
	end
	if mark then
		table.insert(self.__markCardList,card)
	else
		if not skipRecord then
			if antingCard then
				table.insert(self.__putCardList,antingCard)
			else
				table.insert(self.__putCardList,card)
			end
		end
	end
	
	return true
end

function Place:removePutCard()
	table.remove(self.__putCardList)
end

-- 检查吃
function Place:checkChi(card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	local r1 = self.__handleCardBuild[cardType][cardValue+1]
	local r2 = self.__handleCardBuild[cardType][cardValue+2]
	local l1 = self.__handleCardBuild[cardType][cardValue-1]
	local l2 = self.__handleCardBuild[cardType][cardValue-2]
	if (l1 and l2 and l1 > 1 and l2 > 1) then
		return "l1_l2" 
	elseif (r1 and r2 and r1 > 1 and r2 > 1) then
		return "r1_r2"
	elseif (l1 and r1 and l1 > 1 and r1 > 1) then
		return "l1_r1"
	end
	return false
end

function Place:chi(from,card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	local r1 = self.__handleCardBuild[cardType][cardValue+1]
	local r2 = self.__handleCardBuild[cardType][cardValue+2]
	local l1 = self.__handleCardBuild[cardType][cardValue-1]
	local l2 = self.__handleCardBuild[cardType][cardValue-2]
	local card1,card2
	if (l1 and l2 and l1 > 1 and l2 > 1) then
		card1 = l1
		card2 = l2
	elseif (r1 and r2 and r1 > 1 and r2 > 1) then
		card1 = r1
		card2 = r2
	elseif (l1 and r1 and l1 > 1 and r1 > 1) then
		card1 = l1
		card2 = r1
	else
		return false
	end
 
	local success = self:removeCard(card1,1)
	if not success then
		return false
	end
	success = self:removeCard(card2,1)
	if not success then
		return false
	end

	local obj = {value = card,from = from,type = constant.TYPE.CHI}
	table.insert(self.__cardStack,obj)

	return true
end

function Place:checkPeng(card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	return self.__handleCardBuild[cardType][cardValue] >= 2
end

--1、暗杠 手牌拥有四张牌				  =>暗杠
--2、明杠 手牌拥有三张,加上别人出的一张     =>别人放的杠
--3、碰杠 手牌拥有1张                    =>自己摸的明杠
-- 检查是否可以杠
function Place:checkGang(card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	local cardNum = self.__handleCardBuild[cardType][cardValue]

	local result,rmNum
	if cardNum >= 4 then
		rmNum = 4
		result = constant.TYPE.AN_GANG
	elseif cardNum >= 3 then
		rmNum = 3
		result = constant.TYPE.MING_GANG
	elseif cardNum == 1 then
		rmNum = 1
		for _,obj in ipairs(self.__cardStack) do
			if obj.value == card and obj.type == constant.TYPE.PENG then
				result = constant.TYPE.PENG_GANG
				break
			end
		end
	end
	return result,rmNum
end

-- 碰
function Place:peng(from,card)
	if not self:checkPeng(card) then
		return false
	end

	local success = self:removeCard(card,2,nil,true)
	if not success then
		return false
	end

	local obj = {value = card,from = from,type = constant.TYPE.PENG}
	table.insert(self.__cardStack,obj)

	return obj
end

-- 杠
function Place:gang(from,card,lastPutCard)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	local cardNum = self.__handleCardBuild[cardType][cardValue]

	local gangType,rmNum = self:checkGang(card)
	if not gangType then
		return false
	end

	if gangType == constant.TYPE.MING_GANG and (card ~= lastPutCard) then
		return false
	end

	local success = self:removeCard(card,rmNum,nil,false)
	if not success then
		return false
	end

	local obj = {value = card,type=gangType,from=from}
	if gangType == constant.TYPE.PENG_GANG then
		--如果是碰杠,则更改碰变成杠
		for _,item in ipairs(self.__cardStack) do
			if item.value == card and item.type == constant.TYPE.PENG then
				item.type = constant.TYPE.PENG_GANG
				obj = item
				break
			end
		end
	else
		table.insert(self.__cardStack,obj)	
	end
	-- 记录
	if gangType == constant.TYPE.PENG_GANG then
		self.__totalMingGangNum = self.__totalMingGangNum + 1
	elseif gangType == constant.TYPE.MING_GANG then
		self.__totalMingGangNum = self.__totalMingGangNum + 1
	elseif gangType == constant.TYPE.AN_GANG then
		self.__totalAnGangNum = self.__totalAnGangNum + 1
	end

	return obj
end

function Place:getHandleCardList()
	return self.__handleCardList
end

function Place:getHandleCardBuild()
	return self.__handleCardBuild
end

function Place:getCardStack()
	return self.__cardStack
end

function Place:getCurScore()
	return self.__curScore
end

function Place:getTotalScore()
	return self.__totalScore
end

function Place:getLastDrawCard()
	return self.__lastCard
end

function Place:getPutCard()
	return self.__putCardList
end

function Place:getTotalHuNum()
	return self.__totalHuNum
end
function Place:getTotalAnGangNum()
	return self.__totalAnGangNum
end
function Place:getTotalMingGangNum()
	return self.__totalMingGangNum
end

function Place:updateHuNum()
	self.__totalHuNum = self.__totalHuNum + 1
end

function Place:setRecordData(key,value)
	self.__recordData[key] = value
end

function Place:getRecordData(key)
	return self.__recordData[key]
end

function Place:getCardNum(card)
	local cardType,cardValue = self:caculateTypeAndValue(card)
	return self.__handleCardBuild[cardType][cardValue]
end

function Place:getMarkList()
	return self.__markCardList
end

return Place
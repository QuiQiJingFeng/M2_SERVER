local algorithm = require "card_engine.algorithm"
local constant = require "card_engine.constant"
local Place = require "card_engine.Place"
local utils = require "card_engine.utils"
-- 初始化随机种子
math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local engine = {}
-- 引擎初始化
function engine:init(placeNum,round)

	self.__places = {}
	for i=1,placeNum do
		local place = Place.new()
		table.insert(self.__places,place)
	end

	self.__placeNum = placeNum
	self.__round = round
	self.__curRound = 0
	self.__overRound = 0
end

function engine:buildPool()
	self.__cardPool = {}
	for type = 1,3 do
		for value =1,9 do
			for i=1,4 do
				local card = (type-1) * 10 + value
				table.insert(self.__cardPool,card)
			end
		end
	end
end

function engine:setDebugPool(debugPool)
	self.__cardPool = utils:clone(debugPool)
end

function engine:clear()
	self.__mode = constant.BankerMode.YING
	self.__curBankerPos = nil
	self.__flowBureauNum = 0
	self.__lastPutCard = nil
	self.__lastPutPos = nil
	for _,place in ipairs(self.__places) do
		place:clear()
	end
	self.__config = {}
	self.__qiangGangFrom = nil
end

function engine:setDefaultConfig()
	-- 别人出牌的时候是否可以吃碰杠胡(明听也算出牌)
	self.__config.isChi = false
	self.__config.isPeng = true
	self.__config.isGang = true
	self.__config.isHu = true
	-- 是否可以七对胡
	self.__config.isQiDui = false
	-- 癞子牌
	self.__config.huiCard = nil
	-- 抢杠胡
	self.__config.qiangGangHu = true
	-- 有癞子是否可以抢杠胡
	self.__config.qiangGangHuHasHui = nil

	-- 四癞子胡牌
	self.__config.hiPoint = nil
	-- 是否限制只能一个癞子胡牌
	self.__config.onlyOneHuiCardHu = false

	-- 明听还是暗听 默认是暗听
	self.__config.anTing = true
	-- 胡牌是否必须听牌
	self.__config.huMustTing = true
	-- 听牌时候是否可以杠
	self.__config.gangAfterTing = true
	-- 十三幺为特殊牌型,需要特殊处理
	self.__config.shiShanYao = nil
end

--设置列表
function engine:setConfig(config)
	self.__config = {}
	for k,v in pairs(config) do
		self.__config[k] = v
	end
end

function engine:updateConfig(config)
	for k,v in pairs(config) do
		self.__config[k] = v
	end
end

function engine:isAnTing()
	return self.__config.anTing
end

-- 添加额外的牌型,构建最终的牌库
function engine:addExtraCards(extraCards)
	for _,card in ipairs(extraCards) do
		table.insert(self.__cardPool,card)
	end
end

-- 获取牌库
function engine:getCardPool()
	return self.__cardPool
end


-- 获取牌库中牌的数量
function engine:getPoolCardNum()
	return #self.__cardPool
end

-- 洗牌
function engine:sort()
	algorithm:fisherYates(self.__cardPool)
end

--设置庄家模式  赢家连庄,随机庄,顺序庄  默认为赢家连庄
function engine:setBankerMode(mode)
	assert(constant.BankerMode[mode],"error banker mode")
	self.__mode = mode
end

-- 获取本局庄家
function engine:getCurRoundBanker()
	if not self.__curBankerPos then
		self.__curBankerPos = math.random(1,self.__placeNum)
	end
	return self.__curBankerPos
end

function engine:setCurRoundBanker(pos)
	self.__curBankerPos = pos
end

-- 更新下一局庄家的位置
function engine:updateBankerPos(winnerPos)
	if self.__mode == constant.BankerMode.YING then
		self.__curBankerPos = winnerPos
	elseif self.__mode == constant.BankerMode.LIAN then
		local pos = winnerPos + 1
		if pos == self.__placeNum + 1 then
			pos = 1
		end
		self.__curBankerPos = pos 
	elseif self.__mode == constant.BankerMode.RAND then
		self.__curBankerPos = math.random(1,self.__placeNum)
	end
end

-- 当前局开始
function engine:curRoundStart()
	self.__curRound = self.__curRound + 1

	-- 需要记录下当前局所有人的总积分,用来在某些游戏荒庄的时候需要重置杠分
	for _,place in ipairs(self.__places) do
		place:recordOriginScore()
	end
end

-- 重置积分到回合开始前
function engine:resetOriginScore()
	for _,place in ipairs(self.__places) do
		place:resetOriginScore()
	end
end

--发牌
function engine:dealCard(num)
	self:curRoundStart()
	
	local dealCards = {}
	for pos=1,self.__placeNum do
		dealCards[pos] = {}
		local place = self.__places[pos]
		for i=1,num do
			local card = table.remove(self.__cardPool,1)
			place:addCard(card)
			table.insert(dealCards[pos],card)
		end
	end
	return dealCards
end

--设置流局的张数
function engine:setflowBureauNum(num)
	self.__flowBureauNum = num
end

--检测流局
function engine:flowBureau()
	local num = #self.__cardPool
	if num  <= self.__flowBureauNum then
		return true
	end

	return false
end

--移除一张牌 (癞根)
function engine:removeAcard()
	return table.remove(self.__cardPool,1)
end

-- 摸牌 result FLOW/card last 是否从最后一个开始摸
function engine:drawCard(pos,specail,last)
	--检查是否流局
	local is_flow = self:flowBureau()
	if is_flow then
		self:curRoundOver(pos,constant.OVER_TYPE.FLOW)
		return "FLOW"
	end
	local place = self.__places[pos]
	local idx = 1
	if last then
		idx = nil
	end
	local card = table.remove(self.__cardPool,idx)
	if specail then
		card = specail
	end
	place:addCard(card)
	return card
end

function engine:getNextPutPos()
	local pos = self.__lastPutPos + 1
	if pos > #self.__places then
		pos = pos - #self.__places
	end
	return pos
end

function engine:getLastPutPos()
	return self.__lastPutPos
end

function engine:getLastPutCard()
	return self.__lastPutCard
end

-- 出牌
function engine:playCard(pos,card,antingCard,mark)
	local place = self.__places[pos]
	local success = place:removeCard(card,1,antingCard,nil,mark)
	if success then 
		self.__lastPutCard = card
		self.__lastPutPos = pos
	else
		return false
	end
	local stackList = {}

	local check = true
	if self.__config.huMustTing then
		-- 检查是否听牌
		if not place:getTing() then
			check = false
		end
	end
	
	-- 检查出牌人后面的三个人有啥想法
	for idx= pos + 1,pos + self.__placeNum -1 do
		if idx > self.__placeNum then
			idx = idx - self.__placeNum
		end
 		local stackItem = {pos = idx,card = card,operators = {}}
		table.insert(stackList,stackItem)
 
		local obj = self.__places[idx]
		-- 检查碰、杠
		local peng = obj:checkPeng(card)
		local gang = obj:checkGang(card)
		local chi = obj:checkChi(card)
		local stack = stackItem.operators

		if self.__config.gangAfterTing then
			local handleCards
			if obj:getTing() then
				peng = nil
				chi = nil
				if gang then
					if not obj:removeCard(card,3,nil,true) then
						gang = nil
					end
					handleCards = utils:clone(obj:getHandleCardBuild())
					for i=1,3 do
						obj:addCard(card)
					end

					local result = self:__tingCard(handleCards)
					--如果杠了之后还能听牌，则可以杠,否则不能杠
					if not result then
						gang = nil
					end
				end
			end
		end

		if peng and self.__config.isPeng then
			local item1 = "PENG"
			table.insert(stack,item1)
		end
		if gang and self.__config.isGang then
			local item2 = "GANG"
			table.insert(stack,item2)
		end
		
		if chi and self.__config.isChi then
			local item3 = "CHI"
			table.insert(stack,item3)
		end
		if self.__config.isHu and check then
			local handleCards = obj:getHandleCardBuild()
			local hu = algorithm:checkHu(handleCards,card,self.__config)
			local item4 = "HU"
			if hu then
				table.insert(stack,item4)
			end
		end
	end


	local function find(item,opt)
		for i,v in ipairs(item.operators) do
			if v == opt then
				return true
			end
		end
	end

	-- 排序,安装 HU > (PENG/GANG) > CHI 的顺序排列,如果有相同等级的按照pos从小到大的顺序排列
	table.sort(stackList,function(a,b) 
		local a_wight = a.pos * -1
		local b_wight = b.pos * -1

		if find(a,"HU") then
			a_wight = a_wight + 1000
		elseif find(a,"GANG") or find(a,"PENG") then
			a_wight = a_wight + 100
		elseif find(a,"CHI") then
			a_wight = a_wight + 10
		end

		if find(b,"HU") then
			b_wight = b_wight + 1000
		elseif find(b,"GANG") or find(b,"PENG") then
			b_wight = b_wight + 100
		elseif find(b,"CHI") then
			b_wight = b_wight + 10
		end
		return a_wight > b_wight
	end)

	return stackList
end

-- 碰牌
function engine:pengCard(pos)
	local place = self.__places[pos]
	local from = self.__lastPutPos
	local card = self.__lastPutCard
	if not card then
		return false
	end
	local obj =  place:peng(from,card)
	if obj then
		--如果碰牌成功,从牌堆中删除一张牌
		local place2 = self.__places[from]
		place2:removePutCard(from)
	end
	return obj
end
-- multi 乘  add 加 expo 2的指数(不断的翻倍)
function engine:updateScoreFromConf(data,conf,pos)
	local place = self.__places[pos]
	if conf.mode == "ALL" then
		local total = 0
		for index,obj in ipairs(self.__places) do
			if pos ~= index then
				local score = conf.score
				if conf.add then
					local add1 = obj:getRecordData(conf.add) or 0
					local add2 = place:getRecordData(conf.add) or 0
					score = score + add1 + add2
				end
				if conf.oneAdd then
					local add = place:getRecordData(conf.oneAdd) or 0
					score = score + add
				end
				if conf.multi then
					local multi1 = obj:getRecordData(conf.multi) or 0
					local multi2 = place:getRecordData(conf.multi) or 0
					score = score * (multi1 + multi2)
				end
				if conf.expo then
					local expo1 = obj:getRecordData(conf.expo) or 0
					local expo2 = place:getRecordData(conf.expo) or 0
					score = score * 2^(expo1 + expo2)
				end
				obj:updateScore(score * -1)
				total = total + score
			end
		end
		place:updateScore(total)
	elseif conf.mode == "ONE" then
		local obj = self.__places[data.from]
		local score = conf.score
		if conf.add then
			local add1 = obj:getRecordData(conf.add) or 0
			local add2 = place:getRecordData(conf.add) or 0
			score = score + add1 + add2
		end
		obj:updateScore(score * -1)

		place:updateScore(score * 1)
	else
		return false
	end
	return true
end

-- 杠牌 {type,value,from}
function engine:gangCard(pos,card)
	local from = pos
	if self.__lastPutCard == card then
		from = self.__lastPutPos
	end
	local place = self.__places[pos]

	local gangType = place:checkGang(card)
	if not gangType then
		return false
	end

	if self.__config.gangAfterTing then
		if self:getTing(pos) then
			for i=1,1 do
				local handleCards
				--暗杠
				if gangType == constant.TYPE.AN_GANG then
					if not place:removeCard(card,4,nil,true) then
						return false
					end
					handleCards = utils:clone(place:getHandleCardBuild())
					for i=1,4 do
						place:addCard(card)
					end
				elseif gangType == constant.TYPE.MING_GANG then
					if not place:removeCard(card,3,nil,true) then
						return false
					end
					handleCards = utils:clone(place:getHandleCardBuild())
					for i=1,3 do
						place:addCard(card)
					end
				elseif gangType == constant.TYPE.PENG_GANG then
					break
				end

				local result = self:__tingCard(handleCards)
				--如果杠了之后还能听牌，则可以杠,否则不能杠
				if not result then
					return false
				end
			end
		end
	end

	
	--如果可以杠
	--在杠之前要检查其他人是否有抢杠胡
	local stackList = {}
	if gangType and self.__config.qiangGangHu then
		for idx= pos + 1,pos + self.__placeNum -1 do
			if idx > self.__placeNum then
				idx = idx - self.__placeNum
			end
			local canThrough = true
			if not self.__config.qiangGangHuHasHui and self.__config.huiCard then
				--如果抢杠胡不能带癞子牌
				local num = self:getCardNum(idx,self.__config.huiCard)
				if num > 0 then
					canThrough = false
				end
			end
			if canThrough then
		 		local stackItem = {pos = idx,card = card,operators = {}}
				local obj = self.__places[idx]
				local stack = stackItem.operators
				local handleCards = obj:getHandleCardBuild()
				local hu = algorithm:checkHu(handleCards,card,self.__config)
				local item = "HU"
				if hu then
					self.__qiangGangFrom = pos
					table.insert(stackList,stackItem)
					table.insert(stack,item)
				end
			end
		end
	end

	local obj
	if #stackList >= 1 then
		--意味着杠被人抢了
		local stackItem = {pos = pos,card = card,operators = {"GANG"}}
		table.insert(stackList,stackItem)
		obj = "QIANG_GANG"
	else
		obj = place:gang(from,card,self.__lastPutCard)
		if obj then
			place:removePutCard(from)
		end
	end

	return obj,stackList
end

function engine:getRecentDeltScore()
	local list = {}
	for pos,place in ipairs(self.__places) do
		local deltScore = place:getDeltScore()
		list[pos] = deltScore
	end
	return list
end

-- 当局结束
function engine:curRoundOver(pos,overType)
	local winnerPos = self.__curBankerPos
	--如果是流局的话 庄家仍然为上一局的庄家
	if overType == constant.OVER_TYPE.FLOW then
		winnerPos = self.__curBankerPos
	elseif overType == constant.OVER_TYPE.NORMAL then
		winnerPos = pos
	end

	self.__overRound = self.__overRound + 1

	self:updateBankerPos(winnerPos)
end


function engine:caculateFan(refResult,card,place,handleCards)
	-------------------------算番开始-----------------------------
	local fans = {}
	-- 如果可以胡牌,则开始计算番数

	-- 暗卡 三个相同花色，相同的牌数组成的为一个暗卡（刻字）。还有自己摸到的才算暗卡。 碰杠都不算暗卡（暗杠也不算暗卡）
	local anKaNum = 0
	for _,obj in ipairs(refResult.handleStack) do
		if obj.type == "PENG" then
			anKaNum = anKaNum + 1
		end
	end
	fans[constant.FANTYPE.AN_KA] = anKaNum

	-- 门清 没有碰、杠、吃
	if #place:getHandleCardList() >= 13 then
		fans[constant.FANTYPE.MEN_QING] = true
	end

	local cardStack = place:getCardStack()
	-- 清一色
	local qing_yi_se = true
	local value = place:getHandleCardList()[1]
	local cardType = place:caculateTypeAndValue(value)
	for i,value in ipairs(place:getHandleCardList()) do
		local cType = place:caculateTypeAndValue(value)
		if cType ~= cardType then
			qing_yi_se = false
			break
		end
	end
	if qing_yi_se then
		for _,obj in ipairs(cardStack) do
 			local cType = place:caculateTypeAndValue(obj.value)
 			if cType ~= cardType then
				qing_yi_se = false
			break
		end
 		end
	end
	fans[constant.FANTYPE.QING_YI_SE] = qing_yi_se

	
	if refResult.isQiDui then
		--豪华七小对
		if refResult.gangDui then
			fans[constant.FANTYPE.HAO_HUA_QI_XIAO_DUI] = true
		else
			--七小对
			fans[constant.FANTYPE.QI_XIAO_DUI] = true
		end
	end

	--一条龙暂时特殊处理一下
	local long_type
	for type=1,3 do
		local hasLong = true
		for i=1,9 do
			local num = handleCards[type][i]
			if num <= 0 then
				hasLong = false
				break
			end
		end
		if hasLong then
			long_type = type
			break
		end
	end

	if long_type then
		local tempHandleCards = utils:clone(handleCards)
		--减去一条龙的牌
		for i=1,9 do
			tempHandleCards[long_type][i] = tempHandleCards[long_type][i] - 1
		end
		tempHandleCards[long_type][10] = tempHandleCards[long_type][10] - 9

		local hu = algorithm:checkHu(tempHandleCards,card,self.__config)
		if hu then
			fans[constant.FANTYPE.YI_TIAO_LONG] = true
		end
	end

	if refResult.shiShanYao then
		fans[constant.FANTYPE.SHI_SHAN_YAO] = true
	end

	-- 缺门
	local queNum = 0
	for i=1,3 do
 		local has = false
		if handleCards[i][10] > 0 then
			has = true
		end
		if not has then
	 		for _,obj in ipairs(cardStack) do
	 			local cardType = place:caculateTypeAndValue(obj.value)
	 			if i == cardType then
	 				has = true
	 				break
	 			end
	 		end
	 	end
	 	if not has then
	 		queNum = queNum + 1
	 	end
	end
	fans[constant.FANTYPE.QUE_MEN] = queNum


	local tempHandleCards = utils:clone(handleCards)
	if #place:getHandleCardList() % 3 == 2 then
		place:removeCard(card,1,nil,true)
		tempHandleCards = utils:clone(place:getHandleCardBuild())
		place:addCard(card)
	end

	--胡牌列表
	local huCardList = {}
	for i=1,37 do
		if i % 10 ~= 0 then
			local hu = algorithm:checkHu(tempHandleCards,i,self.__config)
			if hu then
				table.insert(huCardList,i)
			end
		end
	end

	-- 掐张 13缺2 或者 单调1张  边张
	if #huCardList == 1 then
		for _,obj in ipairs(refResult.handleStack) do
			if obj.type == "CHI" then
				-- 掐张
				if card == obj.value + 1 then
					fans[constant.FANTYPE.QIA_ZHANG] = true
				end
				-- 边张 
				if (card == obj.value + 2 and card % 10 == 3) or (card == obj.value and card % 10 == 7) then
					fans[constant.FANTYPE.BIAN_ZHANG] = true
				end
			else
				--单调一张 
				if card == obj.value then
					fans[constant.FANTYPE.DAN_DIAO] = true
				end
			end
		end
	end
	-------------------------算番结束-----------------------------
	return fans
end

function engine:__tingCard(handleCards)
	local result = false
	local allCards = self:getAllCardType()
	for i=1,40 do
		local card = allCards[i] and i or nil 
		if card then
			local hu,refResult = algorithm:checkHu(handleCards,card,self.__config)
			if hu then
				result = true
				break
			end
		end
	end
	return result
end

function engine:setTing(pos,card)
	local place = self.__places[pos]
	place:setTing(card)
end

function engine:tingCard(pos,card)
	-- 检测是否听牌
	local place = self.__places[pos]
	
	place:removeCard(card,1,nil,true)
	local handleCards = place:getHandleCardBuild()
	handleCards = utils:clone(handleCards)
	place:addCard(card)
  	
	local result = self:__tingCard(handleCards)
	-- 如果是明听,需要检测其他人的吃碰杠胡
	if result then
		place:setTing(card)
		if self.__config.anTing then
			local antingCard = 99
			if not self:playCard(pos,card,antingCard) then
				return false
			end
			return true,nil,{type = constant.TYPE.TING,value = antingCard,from = pos}
		else
			local stackList = self:playCard(pos,card)
			if not stackList then
				return false
			else
				return true,stackList,{type = constant.TYPE.TING,value = card,from = pos}
			end
		end
	end
	return result
end

function engine:getTing(pos)
	local place = self.__places[pos]
	return place:getTing()
end

function engine:checkHuCard(pos)
	local place = self.__places[pos]
	local card = self.__lastPutCard

	local handleCards = place:getHandleCardBuild()
	local hu,refResult = algorithm:checkHu(handleCards,card,self.__config)
	if not hu then
		return false
	end
	return true
end

-- 胡牌
function engine:huCard(pos,card,specail)
	local place = self.__places[pos]

	if self.__config.huMustTing then
		-- 检查是否听牌
		if not place:getTing() then
			return false
		end
	end
	--如果只能一个癞子胡牌
	if self.__config.onlyOneHuiCardHu then
		local num = place:getCardNum(self.__config.huiCard)
		if num > 1 then
			return false
		end
	end

	local handleCards = place:getHandleCardBuild()
	
	local hu,refResult = algorithm:checkHu(handleCards,card,self.__config)
	if not hu then
		return false
	end


	local fans = engine:caculateFan(refResult,card,place,handleCards)
	refResult.fans = fans

	self:curRoundOver(constant.OVER_TYPE.NORMAL)
	place:updateHuNum()

	local from = pos 

	if not refResult.isZiMo and card == self.__lastPutCard then
		from = self.__lastPutPos
	end
	-- 如果不是自摸，并且牌不是牌桌上的牌 则是抢杠胡
	if not refResult.isZiMo and card ~= self.__lastPutCard then
		if self.__qiangGangFrom then
			from = self.__qiangGangFrom
		end
	end

	local obj = {type = constant.TYPE.HU,value = card,from = from}

	return obj,refResult
end

function engine:getHandleCardBuild(pos)
	local place = self.__places[pos]
	return place:getHandleCardBuild()	
end

function engine:getHandleCardList(pos)
	local place = self.__places[pos]
	return place:getHandleCardList()	
end

function engine:getCurScore(pos)
	local place = self.__places[pos]
	return place:getCurScore()
end

function engine:getTotalScore(pos)
	local place = self.__places[pos]
	return place:getTotalScore()
end

function engine:getHandleCardStack(pos)
	local place = self.__places[pos]
	return place:getCardStack()
end

-- 是否游戏结束
function engine:isGameEnd()
	return self.__round <= self.__overRound
end

function engine:getOverRound()
	return self.__overRound
end

function engine:getCurRound()
	return self.__curRound
end

function engine:setOverRound(overRound)
	self.__overRound = overRound
end

function engine:setCurRound(curRound)
	self.__curRound = curRound
end

function engine:getConstant(...)
	local args = {...}
	local temp = constant
	for i,v in ipairs(args) do
		temp = temp[v]
	end
	return temp
end

function engine:setTotalScore(pos,score)
	local place = self.__places[pos]
	place:setTotalScore(score)
end

function engine:getPlaceNum()
	return self.__placeNum
end

-- 随机骰子
function engine:getRandomNums(n)
	local random_nums = {}
	for i = 1,n do
		local num = math.random(1,6)
		table.insert(random_nums,num)
	end
	return random_nums
end

function engine:getLastDrawCard(pos)
	local place = self.__places[pos]
	return place:getLastDrawCard()
end

function engine:getPutCard(pos)
	local place = self.__places[pos]
	return place:getPutCard()
end

function engine:getTotalHuNum(pos)
	local place = self.__places[pos]
	return place:getTotalHuNum()
end
function engine:getTotalAnGangNum(pos)
	local place = self.__places[pos]
	return place:getTotalAnGangNum()
end
function engine:getTotalMingGangNum(pos)
	local place = self.__places[pos]
	return place:getTotalMingGangNum()
end

function engine:setRecordData(pos,key,value)
	local place = self.__places[pos]
	place:setRecordData(key,value)
end

function engine:getRecordData(pos,key)
	local place = self.__places[pos]
	place:getRecordData(key)
end

function engine:updateRecordData(pos,key,value)
	local place = self.__places[pos]
	local origin = place:getRecordData(key) or 0
	place:setRecordData(key,origin+value)
end

-- 获取某一张牌的数量
function engine:getCardNum(pos,card)
	local place = self.__places[pos]
	return place:getCardNum(card)
end

function engine:getMarkList(pos)
	local place = self.__places[pos]
	return place:getMarkList()
end

--获取所有牌型对应的值
function engine:getAllCardType()
	local allCardType = {
		[1] = "🀇",
		[2] = "🀈",
		[3] = "🀉",
		[4] = "🀊",
		[5] = "🀋",
		[6] = "🀌",
		[7] = "🀍",
		[8] = "🀎",
		[9] = "🀏",

		[11] = "🀐",
		[12] = "🀑",
		[13] = "🀒",
		[14] = "🀓",
		[15] = "🀔",
		[16] = "🀕",
		[17] = "🀖",
		[18] = "🀗",
		[19] = "🀘",

		[21] = "🀙",
		[22] = "🀚",
		[23] = "🀛",
		[24] = "🀜",
		[25] = "🀝",
		[26] = "🀞",
		[27] = "🀟",
		[28] = "🀠",
		[29] = "🀡",

		[31] = "🀀",   --东
		[32] = "🀁",   --南
		[33] = "🀂",   --西
		[34] = "🀃",   --北
		[35] = "🀄",  --中
		[36] = "🀅",   --发
		[37] = "🀆",   --白
		

		[41] = "🀢",   --梅
		[42] = "🀣",   --兰
		[43] = "🀤",   --竹
		[44] = "🀥",   --菊
		[45] = "🀦",   --春
		[46] = "🀧",   --夏
		[47] = "🀨",   --秋
		[48] = "🀩",   --冬

		[49] = "🀪"    --百搭
	}
	return allCardType
end

-- 获取牌库中倒数n张牌
function engine:getPoolLastCards(n)
	local list = {}
	local reduceNum = #self.__cardPool
	for i=1,n do
		local card = self.__cardPool[reduceNum + 1 - i]
		if card then
			table.insert(list,card)
		end
	end
	return list
end

return engine
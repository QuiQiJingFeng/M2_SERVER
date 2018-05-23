--测试用例1
-- 测试发牌
local engine = require "../card_engine/engine"

local function init()
	-- 初始化2人牌局
	engine:init(2)
	engine:clear()
	-- 构建牌库
	engine:buildPool()
	local extra_cards = {}
	--带风 
	--填充牌库
	for i=31,37 do
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
	end

	engine:addExtraCards(extra_cards)

	engine:sort()
	engine:setDefaultConfig()
	-- 设置庄家模式
	engine:setBankerMode("YING")
end


local test = {}

local function drewCards(list1,list2,list3,list4)
	list1 = list1 or {}
	list2 = list2 or {}
	list3 = list3 or {}
	list4 = list4 or {}
	local cardList = list1
	for i,v in ipairs(cardList) do
	    engine:drawCard(1,v)
	end

	local cardList2 = list2
	for i,v in ipairs(cardList2) do
	    engine:drawCard(2,v)
	end

	local cardList3 = list3
	for i,v in ipairs(cardList3) do
	    engine:drawCard(3,v)
	end

	local cardList4 = list4
	for i,v in ipairs(cardList4) do
	    engine:drawCard(4,v)
	end
end
-- 碰、杠的测试用例
function test.case1()
	local args = {
					{11,11,11,11,12,13,15,15,17,18,18,18,19},
					{1,1,1,2,2,2,3,3,3,5,5,12,21}
				 }
	drewCards(table.unpack(args))
	--A摸一张牌
	engine:drawCard(1,28)
	-- A 暗杠
	local obj = engine:gangCard(1,11)
	assert(obj.type==5,"type error")
	assert(obj.value==11,"value error")
	assert(obj.from==1,"from error")
	local num = 0
	local stack = engine:getHandleCardStack(1)
	for _,item in ipairs(stack) do
		if item.type == obj.type and
		   item.value == obj.value and
		   item.from == obj.from then
		   num = num + 1
		end
	end
	assert(num == 1,"stack obj error")

	--A摸一张牌
	engine:drawCard(1,28)
	-- A 出一张牌
	engine:playCard(1,28)
	-- B 摸一张牌
	engine:drawCard(2,18)
	-- B 出一张牌
	engine:playCard(2,18)
	local obj = engine:gangCard(1,18)
	assert(obj.type==4,"type error")
	assert(obj.value==18,"value error")
	assert(obj.from==2,"from error")
	local num = 0
	local stack = engine:getHandleCardStack(1)
	for _,item in ipairs(stack) do
		if item.type == obj.type and
		   item.value == obj.value and
		   item.from == obj.from then
		   num = num + 1
		end
	end
	assert(num == 1,"stack obj error")

	engine:drawCard(1,5)
	engine:playCard(1,5)
	local obj = engine:pengCard(2)
	assert(obj.type==2,"type error")
	assert(obj.value==5,"value error")
	assert(obj.from==1,"from error")

	local num = 0
	local stack = engine:getHandleCardStack(2)
	for _,item in ipairs(stack) do
		if item.type == obj.type and
		   item.value == obj.value and
		   item.from == obj.from then
		   num = num + 1
		end
	end
	assert(num == 1,"stack obj error")

	engine:playCard(2,1)

	engine:drawCard(1,22)
	engine:playCard(1,22)
	
	engine:drawCard(2,5)
	local obj = engine:gangCard(2,5)
	assert(obj.type==3,"type error")
	assert(obj.value==5,"value error")
	assert(obj.from==1,"from error")

	local num = 0
	local stack = engine:getHandleCardStack(2)
	for _,item in ipairs(stack) do
		if item.type == obj.type and
		   item.value == obj.value and
		   item.from == obj.from then
		   num = num + 1
		end
	end
	assert(num == 1,"stack obj error")
end

-- 暗听  先听牌再胡牌
function test.case2()
	local args = {
				{1,2,3,11,12,13,14,15,16,18,18,18,21},
				{4,5,6,7,8,9,23,24,25,26,26,26,28}
			 }
	drewCards(table.unpack(args))
	engine:dealCard(0)
	engine:drawCard(1,25)
	local isTing = engine:tingCard(1,25)
	assert(isTing,"tingCard ERROR")

	engine:drawCard(2,22)
	engine:playCard(2,22)

	--自摸胡测试
	engine:drawCard(1,21)
	local ishu = engine:huCard(1,21)
	assert(ishu,"huCard ERROR")
	assert(engine:getOverRound() == 1,"over round error")
	assert(engine:getCurRound() == 1,"cur round error")

end
-- 暗听 没有听牌 直接胡
function test.case3()
	local args = {
				{1,2,3,11,12,13,14,15,16,18,18,18,21},
				{4,5,6,7,8,9,23,24,25,26,26,26,28}
			 }
	drewCards(table.unpack(args))

	engine:drawCard(2,22)
	engine:playCard(2,22)

	--自摸胡测试
	engine:drawCard(1,21)
	local ishu = engine:huCard(1,21)
	assert(not ishu,"huCard ERROR")
end

-- 明听 先听 听的牌被别人胡
function test.case4()
	engine:updateConfig({anTing = false})
	local args = {
			{1,2,3,11,12,13,14,15,16,18,18,18,21},
			{4,5,6,7,8,9,23,24,25,26,26,26,28}
		 }
	drewCards(table.unpack(args))

	engine:drawCard(1,11)
	local isTing = engine:tingCard(1,11)
	assert(isTing,"tingCard ERROR")

	engine:drawCard(2,21)
	local isTing,stack = engine:tingCard(2,21)
	assert(isTing,"tingCard ERROR")
	assert(stack,"tingCard ERROR")
	assert(stack[1].card == 21,"胡牌的牌值不对")
	assert(stack[1].pos == 1,"胡牌的人不对")
	local hasHu = false
	for i,item in pairs(stack[1].operators) do
		if item == "HU" then
			hasHu = true
			break;
		end
	end
	assert(hasHu,"stack ERROR")

	local obj = engine:huCard(1,21)
	assert(obj,"huCard ERROR")
	assert(obj.from == 2,"hu from ERROR")
	assert(obj.value == 21,"hu value ERROR")
end

-- 测试抢杠胡(抢杠胡是自摸的碰杠被人抢了)
function test.case5()
	local args = {
			{1,2,3,11,12,13,14,15,16,17,18,28,28},
			{4,5,6,7,8,9,23,24,25,26,27,29,29}
		 }
	drewCards(table.unpack(args))
	engine:drawCard(2,28)
 	engine:playCard(2,28)

 	local obj = engine:pengCard(1)
 	assert(obj.type == 2,"pengCard ERROR")
 	assert(obj.from == 2,"pengCard ERROR")
 	assert(obj.value == 28,"pengCard ERROR")

	local num = 0
	local stack = engine:getHandleCardStack(1)
	for _,item in ipairs(stack) do
		if item.type == obj.type and
		   item.value == obj.value and
		   item.from == obj.from then
		   num = num + 1
		end
	end
	assert(num == 1,"stack obj error")


 	engine:playCard(1,18)

 	engine:drawCard(2,27)
 	engine:playCard(2,27)

 	engine:drawCard(1,28)

 	local obj,stackList = engine:gangCard(1,28)
 	assert(obj.type == 3,"gangCard ERROR")
 	assert(obj.from == 2,"gangCard ERROR")
 	assert(obj.value == 28,"gangCard ERROR")

 	--2位置胡 28 这张牌
 	assert(stackList[1].card == 28,"STACK ERROR")
 	assert(stackList[1].pos == 2,"STACK ERROR")
 	local hu = false
 	for k,v in pairs(stackList[1].operators) do
 		if v == "HU" then
 			hu = true
 			break;
 		end
 	end
 	assert(hu,"ERROR")
 end

-- 测试4个癞子胡牌
function test.case6()

	local config = {isChi = false,isPeng = true,isGang=true,isHu=true,
					isQiDui = true,huiCard=3,qiangGangHu = true,hiPoint=true}
	engine:setConfig(config)
	local args = {
		{1,2,3,11,3,3,3,3,16,17,18,28,28},
		{4,5,6,7,8,9,23,24,25,26,27,29,29}
	 }
	drewCards(table.unpack(args))

	engine:drawCard(1,4)
	local obj = engine:huCard(1,4)
	assert(obj.type == 6,"HU ERROR")
	assert(obj.value == 4,"HU ERROR")
end

--测试癞子胡牌 测试七对胡
function test.case7()
	local config = {isChi = false,isPeng = true,isGang=true,isHu=true,
					isQiDui = true,huiCard=3,qiangGangHu = true,hiPoint=true,
				}
	engine:setConfig(config)
	local args = {
		{1,2,3,4,5,6,7,8,9,16,17,18,28},
		{1,1,2,2,13,13,4,4,5,5,6,6,7}
	 }
	drewCards(table.unpack(args))
	--普通癞子胡(多个癞子)牌测试
	engine:drawCard(1,3)
	local obj = engine:huCard(1,3)
	assert(obj.type == 6,"HU ERROR")
	assert(obj.value == 3,"HU ERROR")
	assert(obj.from == 1,"HU ERROR")
	
	--多癞子不能胡牌测试
	engine:updateConfig({onlyOneHuiCardHu = true})
	local obj = engine:huCard(1,3)
	assert(not obj,"胡牌错误，多个癞子不能胡牌")

	--测试七对胡
	engine:drawCard(2,7)
	local obj = engine:huCard(2,7)
	assert(obj.type == 6,"HU ERROR")
	assert(obj.value == 7,"HU ERROR")
	assert(obj.from == 2,"HU ERROR")

	engine:updateConfig({isQiDui=false})
	local obj = engine:huCard(2,7)
	assert(not obj,"胡牌错误,七对开关没有开，无法胡七对")
end

-- 检测流局
function test.case8()
	-- 设置流局的张数
	engine:setflowBureauNum(20)
	local cardNum = engine:getPoolCardNum()
	local args = {
		{1,2,3,4,5,6,7,8,9,16,17,18,28},
		{1,1,2,2,13,13,4,4,5,5,6,6,7}
	 }
	drewCards(table.unpack(args))

	for i=1,cardNum do
		local pos = i % 2 + 1
		local result = engine:drawCard(pos)
		if result == "FLOW" then
			break
		end
		if i == 35 then
			engine:setflowBureauNum(30)
		end
		engine:playCard(pos,result)
	end
	local curNum = engine:getPoolCardNum()
	assert(curNum == 30)
end

-- 测试积分
function test.case9()
	-- 初始化4人牌局
	engine:init(4)
	engine:clear()
	-- 构建牌库
	engine:buildPool()
	local extra_cards = {}
	--带风 
	--填充牌库
	for i=31,37 do
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
	end

	engine:addExtraCards(extra_cards)

	engine:sort()
	engine:setDefaultConfig()
	-- 设置庄家模式
	engine:setBankerMode("YING")

	-- 更新积分 玩家B 赢 玩家A
	engine:updateScoreFromConf({from = 1},{mode = "ONE" ,score = 10},2)
	-- B 预期积分为10 A 预期积分为 -10 C 0 D 0

	assert(engine:getTotalScore(2) == 10)
	assert(engine:getTotalScore(1) == -10)
	assert(engine:getTotalScore(3) == 0)
	assert(engine:getTotalScore(4) == 0)


	engine:init(4)
	-- 更新积分 玩家B 赢所有玩家 10 积分
	engine:updateScoreFromConf(nil,{mode = "ALL" ,score = 10},2)
	-- 预期 B:30 A:-10 B:-10 C:-10
	assert(engine:getTotalScore(1) == -10)
	assert(engine:getTotalScore(2) == 30)
	assert(engine:getTotalScore(3) == -10)
	assert(engine:getTotalScore(4) == -10)

	------------------作用于输赢双方的积分操作--------------
	engine:init(4)
	-- 特殊处理(类似于下注的操作 增加积分) 例如: 下跑 A 跑1 B 跑1 C 没跑 D 没跑
	-- B 多赢A 2跑分  B 赢C 1跑分  B 赢D 1跑分
	engine:setRecordData(1,"xiapao",1)
	engine:setRecordData(2,"xiapao",1)
	-- 更新积分 玩家B 赢所有玩家 10 积分 并且算上跑分
	engine:updateScoreFromConf(nil,{mode = "ALL" ,score = 10,add="xiapao"},2)
	-- 预期 B:12+11+11 = 34  A: -12  C: -11 D:-11
	assert(engine:getTotalScore(1) == -12)
	assert(engine:getTotalScore(2) == 34)
	assert(engine:getTotalScore(3) == -11)
	assert(engine:getTotalScore(4) == -11)

	--例子2: 飘处理(动态下注操作) 2的指数翻倍积分
	engine:init(4)
	--A 飘了1个
	engine:updateRecordData(1,"piao",1)
	--B 飘了2个
	engine:updateRecordData(2,"piao",2)
	--C 飘了1个
	engine:updateRecordData(3,"piao",1)

	-- 更新积分 玩家A 赢所有玩家 10 积分 并且算上飘
	engine:updateScoreFromConf(nil,{mode = "ALL" ,score = 10,expo="piao"},1)
	-- 预期 A: 10*2^3 + 10*2^2 + 10*2 = 80 + 40 +20 = 140
	-- B: -80 C:-40 D:-20
	assert(engine:getTotalScore(1) == 140)
	assert(engine:getTotalScore(2) == -80)
	assert(engine:getTotalScore(3) == -40)
	assert(engine:getTotalScore(4) == -20)

	engine:init(4)
	--特殊处理之补花操作
	-- 补花 只在自己胡牌的时候生效,并且只计算自己的
	-- 例如: A 自摸胡牌赢10分, 并且补了2花   B 补了1个花 C/D 没有补花
	-- 那么预期 A 赢B 12分(不算B补的花)  A赢C 12 分  A赢D 12分
	--更新积分 玩家A 赢所有玩家10 积分 并且算上补花分
	engine:updateRecordData(1,"hua",2)
	engine:updateRecordData(2,"hua",1)
	engine:updateScoreFromConf(nil,{mode = "ALL" ,score = 10,oneAdd="hua"},1)
	assert(engine:getTotalScore(1) == 36)
	assert(engine:getTotalScore(2) == -12)
	assert(engine:getTotalScore(3) == -12)
	assert(engine:getTotalScore(4) == -12)

	engine:init(4)
	-- 混合处理  又有跑分 又有花分
	-- A 跑1 花2  B 跑1 花1 C 花1
	-- 预期:A自摸赢10分, 则:
	-- A 赢 B 2 + 2 + 10 = 14
	-- A 赢 C 1 + 2 + 10 = 13
	-- A 赢 D 1 + 2 + 10 = 13
	engine:updateRecordData(1,"pao",1)
	engine:updateRecordData(1,"hua",2)
	engine:updateRecordData(2,"pao",1)
	engine:updateRecordData(2,"hua",1)
	engine:updateRecordData(3,"hua",1)
	engine:updateScoreFromConf(nil,{mode = "ALL" ,score = 10,oneAdd="hua",add="pao"},1)

	assert(engine:getTotalScore(1) == 40)
	assert(engine:getTotalScore(2) == -14)
	assert(engine:getTotalScore(3) == -13)
	assert(engine:getTotalScore(4) == -13)
end

-- 测试麻将的番
function test.case10()
	engine:init(3)
	local config = {isChi = false,isPeng = true,isGang=true}
	engine:setConfig(config)
	local args = {
			{1,2,3,11,12,13,14,15,16,13,13,13,19},
			{1,2,3,5,6,7,11,12,13,15,15, 19,18},
			{1,3, 5,6,7, 11,12,13, 15,15, 17,18,19},
	 }
	drewCards(table.unpack(args))

	engine:drawCard(1,19)
	local obj,refResult = engine:huCard(1,19)
	assert(obj,"ERROR_HU_CARD")
	assert(refResult.fans["MEN_QING"],"门清")
	assert(refResult.fans["QUE_MEN"]==1,"缺门")
	assert(refResult.fans["DAN_DIAO"],"单调")
	assert(refResult.fans["AN_KA"] == 1,"暗卡")

	engine:drawCard(2,17)
	local obj,refResult = engine:huCard(2,17)
	assert(obj,"ERROR_HU_CARD")
	assert(refResult.fans["BIAN_ZHANG"],"边张")

	engine:drawCard(3,2)
	local obj,refResult = engine:huCard(3,2)
	assert(obj,"ERROR_HU_CARD")
	assert(refResult.fans["QIA_ZHANG"],"掐张")

end

for i=1,10 do
	local str = "case"..i
	local func = test[str]
	if not func then
		break
	end
	init()
	func()
	print("测试用例["..i.."]通过！！！")
end

 

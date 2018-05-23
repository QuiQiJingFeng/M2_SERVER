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
	engine:settingConfig()
	-- 设置庄家模式
	engine:setBankerMode("YING")
	-- 设置流局的张数
	engine:setflowBureauNum(2)
end


local test = {}

local function drewCards(list1,list2)
	print("开始发牌:")
	local cardList = list1
	for i,v in ipairs(cardList) do
	    engine:drawCard(1,v)
	end
	print("A玩家手牌:",table.concat(cardList,","))

	local cardList2 = list2
	for i,v in ipairs(cardList2) do
	    engine:drawCard(2,v)
	end
	print("B玩家手牌:",table.concat(cardList2,","))
end
-- 碰、杠的测试用例
function test.case1()
	print("--------检测碰杠----------")
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
	print("暗杠测试通过")

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
	print("明杠测试通过")


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
	print("碰测试通过")

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
	print("碰杠测试通过")
	print("用例1测试通过")
end

-- 暗听  先听牌再胡牌
function test.case2()
	local args = {
				{1,2,3,11,12,13,14,15,16,18,18,18,21},
				{4,5,6,7,8,9,23,24,25,26,26,26,28}
			 }
	drewCards(table.unpack(args))
	engine:drawCard(1,25)
	local isTing = engine:tingCard(1,25)
	assert(isTing,"tingCard ERROR")

	engine:drawCard(2,22)
	engine:playCard(2,22)

	--自摸胡测试
	engine:drawCard(1,21)
	local ishu = engine:huCard(1,21)
	assert(ishu,"huCard ERROR")
	print("用例2 测试通过")
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
	print("用例3 测试通过")
end

-- 明听 先听 听的牌被别人胡
function test.case4()
	engine:settingConfig({anTing = false})
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
	print("用例4测试通过")
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
 	print("测试用例5通过")
end

for i=1,10 do
	local str = "case"..i
	local func = test[str]
	if not func then
		break
	end
	init()
	func()
end





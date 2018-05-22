local engine = require "card_engine/engine"

engine:init(2)
engine:clear()
engine:buildPool()
local extra_cards = {}
for i=41,48 do
	table.insert(extra_cards,i)
end

--带风 
--填充牌库
for i=31,37 do
	table.insert(extra_cards,i)
	table.insert(extra_cards,i)
	table.insert(extra_cards,i)
	table.insert(extra_cards,i)
end
 
engine:addExtraCards(extra_cards)


--洗牌
engine:sort()
engine:settingConfig()
-- 设置庄家模式
engine:setBankerMode("YING")
-- 设置流局的张数
engine:setflowBureauNum(2)

local cardList = {1,2,3,11,12,13,15,15,17,18,21}
for i,v in ipairs(cardList) do
    engine:drawCard(1,v)
end

local cardList2 = {1,1,1,2,2,2,3,3,3,5,5,5,21,22}
for i,v in ipairs(cardList2) do
    engine:drawCard(2,v)
end

engine:playCard(2,22)
engine:drawCard(2,22)

local result,stack_list = engine:tingCard(2,22)
print("FYD--->>>玩家2报听 ",result)

local result,stack_list = engine:tingCard(1,21)
print("FYD====>>>玩家1报听 = ",result)

if stack_list then
	for i,obj in ipairs(stack_list) do
		for k,v in pairs(obj.operators) do
			print(k,v)
		end
	end
end
print("FYD-------------")
local cards = engine:getPutCard(2)
for i,v in ipairs(cards) do
	print(i,v)
end








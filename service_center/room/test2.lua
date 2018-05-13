local engine = require "card_engine/engine"

engine:init(2)
engine:clear()
engine:setTotalHuNum(1,0)
engine:setTotalAnGangNum(1,0)
engine:setTotalMingGangNum(1,0)
engine:buildPool()
local extra_cards = {35,35,35,35}
engine:addExtraCards(extra_cards)
--洗牌
engine:sort()
engine:settingConfig({isHu=false,isQiDui=true,huiCard=35,hiPoint=true})
-- 设置庄家模式
engine:setBankerMode("YING")
-- 设置流局的张数
engine:setflowBureauNum(2)

local cardList = {1,2,3,5,5,9,9,9,4,4,6,6,35,9}
for i,v in ipairs(cardList) do
    engine:drawCard(1,v)
end
local cardList2 = {5,6,7,13,13,14,15}
for i,v in ipairs(cardList2) do
    engine:drawCard(2,v)
end

engine:huCard(1,35)


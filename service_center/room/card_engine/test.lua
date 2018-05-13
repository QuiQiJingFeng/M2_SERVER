local algorithm = require("algorithm")

local handleCardBuild = {}
local function caculateTypeAndValue(card)
	local cardType = math.floor(card / 10) + 1
	local cardValue = card % 10
	return cardType,cardValue
end

local function addCard(card)
	local cardType,cardValue = caculateTypeAndValue(card)
	handleCardBuild[cardType][10] = handleCardBuild[cardType][10] + 1
	handleCardBuild[cardType][cardValue] = handleCardBuild[cardType][cardValue] + 1
end

function main()
	local isQiDui = nil
	local huiCard = 35
	for type =1,4 do
		for value=1,10 do
			if not handleCardBuild[type] then
				handleCardBuild[type] = {}
			end
			handleCardBuild[type][value] = 0
		end
	end

	local cardList = {1,2,3,5,5,9,9,9,4,4,6,6,35,35}
	for i,card in ipairs(cardList) do
		addCard(card)
	end
	local config = {}
	-- 是否可以七对胡
	config.isQiDui = isQiDui
	-- 癞子牌
	config.huiCard = huiCard
	 -- 抢杠胡
	config.qiangGangHu = true
	-- 四红中胡牌
	config.hiPoint = true 

	local result = algorithm:checkHu(handleCardBuild,35,config)
	print("FYD---->>>result ==>")
	print(result)
end

main();
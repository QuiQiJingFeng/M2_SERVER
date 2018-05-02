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
	local isQiDui = false
	local huiCard = nil
	for type =1,4 do
		for value=1,10 do
			if not handleCardBuild[type] then
				handleCardBuild[type] = {}
			end
			handleCardBuild[type][value] = 0
		end
	end

	local cardList = {11,11,22,22,33,33,2,2,12,12,3,3,4,4}
	for i,card in ipairs(cardList) do
		addCard(card)
	end

	local result = algorithm:checkHu(handleCardBuild,isQiDui,huiCard)
	print("FYD---->>>result ==>")
	print(result)
end

main();
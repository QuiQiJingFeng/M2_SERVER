local utils = require("utils")
local algorithm = {}

--FisherYates洗牌算法
function algorithm:fisherYates(cardPool)
    for i = #cardPool,1,-1 do
        --在剩余的牌中随机取一张
        local j = math.random(i)
        --交换i和j位置的牌
        local temp = cardPool[i]
        cardPool[i] = cardPool[j]
        cardPool[j] = temp
    end
end

local function caculateTypeAndValue(card)
	local cardType = math.floor(card / 10) + 1
	local cardValue = card % 10
	return cardType,cardValue
end

local function addCard(handleCards,card)
	local cardType,cardValue = caculateTypeAndValue(card)
	handleCards[cardType][10] = handleCards[cardType][10] + 1
	handleCards[cardType][cardValue] = handleCards[cardType][cardValue] + 1
end

function algorithm:checkHu(handleCards,card,isQiDui,huiCard)

	handleCards = utils:clone(handleCards)
	local refResult = {handleStack = {},jiangOK=false,isZiMo = true,isQiDui = false}
	--校验一下
	local iTotalCardNum = 0
	for i=1,5 do
		local iTypeCardNum = 0;
		for j=1,9 do
			iTypeCardNum = iTypeCardNum + handleCards[i][j];
			iTotalCardNum = iTotalCardNum + handleCards[i][j];
		end
		if iTypeCardNum ~= handleCards[i][10] then
			print(string.format("TypeCardNum Error iTypeCardNum[%d] [%d][%d]\n",iTypeCardNum,i,handleCards[i][10]));
			return false
		end
	end

	if math.floor(iTotalCardNum % 3) ~= 2 then
		if math.floor((iTotalCardNum + 1) % 3) ~= 2 then
			print(string.format("iTotalCardNum Error iTotalCardNum[%d]\n",iTotalCardNum))
			return false
		else
			addCard(handleCards,card)
			refResult.isZiMo = false
		end
	end

	local duiNum = 0
	for type = 1,4 do
		for value = 1,9 do
			if handleCards[type][value] == 2 then
				duiNum = duiNum + 1
			elseif handleCards[type][value] == 4 then
				duiNum = duiNum + 2
			end
		end
	end

	if isQiDui and duiNum == 7 then
		refResult.isQiDui = true
		return true,refResult
	end
 
	if not self:analyze(handleCards,1,refResult) then
		return false
	end

	return true,refResult
end

function algorithm:analyze(handleCards,type,refResult)
	local result,index
	--如果该类型的牌数量为0
	if handleCards[type][10] == 0 then
		result = true;
		if type < 4 then
			result = self:analyze(handleCards,type+1,refResult)
		end
		return result;
	end

	--否则 循环查找该类型中不为0的有效牌
	for i=1,9 do
		if handleCards[type][i] ~= 0 then
			index = i
			break
		end
	end
	local card = handleCards[type][index]
	-- 检查刻子
	if handleCards[type][index] >= 3 then
		handleCards[type][index] = handleCards[type][index] - 3
		handleCards[type][10] = handleCards[type][10] - 3
		-- 假设该牌是组合成一个刻子的,然后继续分析,如果最终可以组成一个胡牌组合则result为true,否则为false
		result = self:analyze(handleCards,type,refResult)

		handleCards[type][index] = handleCards[type][index] + 3
		handleCards[type][10] = handleCards[type][10] + 3

		if result then
			local obj = {value = card,type = "PENG"}
			table.insert(refResult.handleStack,obj)
			return result
		end
	end

	-- 检查是否可以构成 连
	if type <= 3 then
		--检测是否可以构成 连
		if index < 8 and handleCards[type][index+1] > 0 and handleCards[type][index+2]>0 then
			handleCards[type][index] = handleCards[type][index] - 1;
			handleCards[type][index+1] = handleCards[type][index+1] - 1;
			handleCards[type][index+2] = handleCards[type][index+2] - 1;
			handleCards[type][10] = handleCards[type][10] - 3;
			result=self:analyze(handleCards,type,refResult)
			handleCards[type][index] = handleCards[type][index]+ 1;
			handleCards[type][index+1] = handleCards[type][index+1] + 1;
			handleCards[type][index+2] = handleCards[type][index+2] + 1;
			handleCards[type][10] = handleCards[type][10] + 3;

			if result then
				local obj = {value = card,type = "CHI"}
				table.insert(refResult.handleStack,obj)
				return result
			end
		end
	end

	-- 如果该牌无法组成刻子和连 则检查将牌,并且将牌只能有一个
	if not refResult.jiangOK then
		local jiangNum = 0
		if handleCards[type][index] >= 2 then
			jiangNum = 2
		else
			return false
		end

		refResult.jiangOK = true
		handleCards[type][index] = handleCards[type][index] - jiangNum
		handleCards[type][10] = handleCards[type][10] - jiangNum

		result = self:analyze(handleCards,type,refResult)

		handleCards[type][index] = handleCards[type][index] + jiangNum
		handleCards[type][10] = handleCards[type][10] + jiangNum
		if result then
			local obj = {value = card,type = "JIANG"}
			table.insert(refResult.handleStack,obj)
			return result
		end
	end
end


























return algorithm
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
	local refResult = {handleStack = {},jiangOK=false,isZiMo = true,isQiDui = false,huiNum = 0,huiCard=huiCard}
	--校验一下
	local iTotalCardNum = 0
	for i=1,#handleCards do
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
	-- 检查七对
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
	
	if huiCard then
		print("癞子牌为:",huiCard)
		--会牌的类型和值
		local cardType,cardValue = caculateTypeAndValue(huiCard)
		local huiNum = handleCards[cardType][cardValue];
		refResult.huiNum = huiNum
		--更新牌型数量 去掉癞子的数量
		handleCards[cardType][10] = handleCards[cardType][10] - huiNum
		--将癞子的个数设置为0
		handleCards[cardType][cardValue] = 0;
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
		-- 万、条、筒、风 都可以用3n+3m+2x计算
		-- 花牌需要根据规则另外算
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
	local cardNum = handleCards[type][index]
	local card = (type-1) * 10 + index
	print("检查牌值 ==> ",card," 数量=",handleCards[type][index])
	-- 检查刻子
	if handleCards[type][index] >= 3 then
		handleCards[type][index] = handleCards[type][index] - 3
		handleCards[type][10] = handleCards[type][10] - 3
		-- 假设该牌是组合成一个刻子的,然后继续分析,如果最终可以组成一个胡牌组合则result为true,否则为false
		result = self:analyze(handleCards,type,refResult)

		handleCards[type][index] = handleCards[type][index] + 3
		handleCards[type][10] = handleCards[type][10] + 3

		if result then
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
				return result
			end
		end

		--如果癞子数量大于0
		if refResult.huiNum > 0 then
			--癞子数量-1
			refResult.huiNum = refResult.huiNum - 1
			--检测如果有一张会牌的情况下 组合成连的情况
			-- a肯定是存在的 并且大于0的,但是bc就不一定了,b/c 有可能为nil 也有可能为0
			local a = handleCards[type][index] 
			local b = handleCards[type][index+1] or 0
			local c = handleCards[type][index+2] or 0
			local num = 1
			if b > 0 then num = num + 1 end
			if c > 0 then num = num + 1 end

			-- 2 缺 1(癞子)
			if num == 2 then
				handleCards[type][index] = handleCards[type][index] -1;
				if b > 0 then
					handleCards[type][index+1] = handleCards[type][index+1] -1;
				elseif c > 0 then
					handleCards[type][index+2] = handleCards[type][index+2] -1;
				end
				handleCards[type][10] = handleCards[type][10] - 2;

				result = self:analyze(handleCards,type,refResult);

				handleCards[type][index] = handleCards[type][index] + 1;
				if b > 0 then
					handleCards[type][index+1] = handleCards[type][index+1] + 1;
				elseif c > 0 then
					handleCards[type][index+2] = handleCards[type][index+2] + 1;
				end
				handleCards[type][10] = handleCards[type][10] + 2;

				if result then
					-- 吃或者碰都可以
					return result;
				end
			end
			
			-- 1 缺 2
			if num == 1 and refResult.huiNum > 0 then
				refResult.huiNum = refResult.huiNum - 1
				handleCards[type][index] = handleCards[type][index] - 1;
				handleCards[type][10] = handleCards[type][10] - 1;

				result = self:analyze(handleCards,type,refResult);

				handleCards[type][index] = handleCards[type][index] + 1;
				handleCards[type][10] = handleCards[type][10] + 1;
				refResult.huiNum = refResult.huiNum + 1
				if result then
					-- 吃或者碰都可以
					return result;
				end
			end
			refResult.huiNum = refResult.huiNum + 1
		end
	end

	-- 如果该牌无法组成刻子和连 则检查将牌,并且将牌只能有一个
	if not refResult.jiangOK then
		local jiangNum = 0
		local useHuiNum = 0
		if handleCards[type][index] >= 2 then
			jiangNum = 2
		else
			if refResult.huiNum > 0 then
				jiangNum = 1
				refResult.huiNum = refResult.huiNum - 1;
			else
				return false
			end
		end

		refResult.jiangOK = true
		handleCards[type][index] = handleCards[type][index] - jiangNum
		handleCards[type][10] = handleCards[type][10] - jiangNum

		result = self:analyze(handleCards,type,refResult)

		handleCards[type][index] = handleCards[type][index] + jiangNum
		handleCards[type][10] = handleCards[type][10] + jiangNum
		if result then
			return result
		end
		-- 如果jiangNum == 1 则补上一张癞子牌
		if jiangNum == 1 then
			refResult.huiNum = refResult.huiNum + 1;
		end
		refResult.jiangOK = false;
	
	-- 检查是是否能成为碰
	else
		local cardNum,huiNum
		if refResult.huiNum > 0 and handleCards[type][index] >= 2 then
			cardNum = 2
			huiNum = 1
		elseif refResult.huiNum >= 2 then
			cardNum = 1
			huiNum = 2
		end
		if cardNum and huiNum then
			refResult.huiNum = refResult.huiNum - huiNum;

			handleCards[type][index] = handleCards[type][index] - cardNum;
			handleCards[type][10] = handleCards[type][10] - cardNum;

			result = self:analyze(handleCards,type,refResult);

			handleCards[type][index] = handleCards[type][index] + cardNum;
			handleCards[type][10] = handleCards[type][10] + cardNum;

			if result then
				return result;
			end

			refResult.huiNum = refResult.huiNum + huiNum;
		end
	end

	return false
end


























return algorithm
local judgecard = {}


---特殊处理  检测是否4个红中，以及处理7对 红中不能作为万能牌使用的问题
function judgecard:JudgeSpecialHu(allPai,resultType,bQiDuiHu)
	--如果红中大于4个则直接胡
	if resultType.iHuiNum >= 4 then
		return true
	end

	if bQiDuiHu and resultType.iChiNum + resultType.iPengNum == 0 then
		local iNums = 0
		for i=1,4 do
			for j=1,9 do
				if allPai[i][j] == 2 then
					iNums = iNums + 1
				elseif allPai[i][j] == 4 then
					iNums = iNums + 2
				end
			end
		end
		--7对 红中不能当成万能牌
		if resultType.iHuiNum % 2 == 0 and iNums + math.floor(resultType.iHuiNum/2) == 7 then
			return true
		end
	end

	return false
end

function judgecard:JudgeIfHu2(allPai,resultType,bQiDuiHu)
	local iTotalCardNum = 0

	--校验一下
	for i=1,4 do
		local iTypeCardNum = 0;
		for j=1,9 do
			iTypeCardNum = iTypeCardNum + allPai[i][j];
			iTotalCardNum = iTotalCardNum + allPai[i][j];
		end
		if iTypeCardNum ~= allPai[i][10] then
			print(string.format("TypeCardNum Error iTypeCardNum[%d] [%d][%d]\n",iTypeCardNum,i,allPai[i][10]));
			return false
		end
	end

	if iTotalCardNum ~= 2 and iTotalCardNum ~= 5 and iTotalCardNum ~= 8 and iTotalCardNum ~= 11 and iTotalCardNum ~= 14 then
		print(string.format("iTotalCardNum Error iTotalCardNum[%d]\n",iTotalCardNum));
		return false
	end
	
	--会牌的类型和值
	local value = resultType.iHuiCard
	local iType = math.floor(value / 10) + 1
	local iValue = value % 10
	local iHuiNum = allPai[iType][iValue];
	resultType.iHuiNum = iHuiNum

	--更新牌型数量 去掉红中的数量
	allPai[iType][10] = allPai[iType][10] - iHuiNum
	--将红中的个数设置为0
	allPai[iType][iValue] = 0;

	--检测特殊胡牌类型
	if self:JudgeSpecialHu(allPai,resultType, bQiDuiHu) then
		return true
	elseif self:JudgeNormalHu(allPai,resultType) then
		return true
	end

	return false
end

--正常流程 检测胡牌
function judgecard:JudgeNormalHu(allPai,resultType)
	if self:Analyze(allPai,1,resultType) then
		return true
	end

	return false
end

--分析胡牌  检测同一个类型的牌 的所有的组合
function judgecard:Analyze(allPai,iType,resultType)
	local index = nil
	local result
	--如果该类型的牌数量为0
	if allPai[iType][10] == 0 then
		result = true;

		if iType <= 3 then
			result = self:Analyze(allPai,iType+1,resultType);
		else
			if resultType.iHuiNum >= 2 then
				if not resultType.bJiangOK then
					local value = resultType.iHuiCard
					local iType = math.floor(value / 10) + 1
					local iValue = value % 10

					resultType.bJiangOK = true;
					resultType.jiangType.iType = iType;
					resultType.jiangType.iValue = iValue;
				end
			end
		end
		return result;
	end
	--否则 循环查找该类型中不为0的有效牌
	for i=1,9 do
		if allPai[iType][i] ~= 0 then
			index = i
			break;
		end
	end
-- 333 4 5
	--检查该牌 是否可以构成 3刻子
	if allPai[iType][index] >= 3 then

		allPai[iType][index] = allPai[iType][index] - 3;
		allPai[iType][10] = allPai[iType][10] - 3;

		result = self:Analyze(allPai,iType,resultType);

		allPai[iType][index] = allPai[iType][index] + 3;
		allPai[iType][10] = allPai[iType][10] + 3;

		if result then
			resultType.pengType[resultType.iPengNum+1].iType = iType;
			resultType.pengType[resultType.iPengNum+1].iValue = index;
			resultType.iPengNum = resultType.iPengNum + 1;
	
			return result;
		end
	end

	--如果牌的类型是 万条筒
	if iType <= 3 then
		--检测是否可以构成 连
		if index < 8 and allPai[iType][index+1] > 0 and allPai[iType][index+2]>0 then
			allPai[iType][index] = allPai[iType][index] - 1;
			allPai[iType][index+1] = allPai[iType][index+1] - 1;
			allPai[iType][index+2] = allPai[iType][index+2] - 1;
			allPai[iType][10] = allPai[iType][10] - 3;
			result=self:Analyze(allPai,iType,resultType);
			allPai[iType][index] = allPai[iType][index]+ 1;
			allPai[iType][index+1] = allPai[iType][index+1] + 1;
			allPai[iType][index+2] = allPai[iType][index+2] + 1;
			allPai[iType][10] = allPai[iType][10] + 3;

			if result then
				resultType.chiType[resultType.iChiNum+1].iType = iType;
				resultType.chiType[resultType.iChiNum+1].iFirstValue = index;
				resultType.iChiNum = resultType.iChiNum + 1;
				return result;
			end
		end

		--如果红中数量大于0
		if resultType.iHuiNum > 0 then
			--会牌数量-1
			resultType.iHuiNum = resultType.iHuiNum - 1
			--检测如果有一张会牌的情况下 组合成连的情况
			--A X C
			if index < 8 and allPai[iType][index+1]==0 and allPai[iType][index+2]>0 then
				allPai[iType][index] = allPai[iType][index] -1;
				allPai[iType][index+2] = allPai[iType][index+2] -1;
				allPai[iType][10] = allPai[iType][10] - 2;
				result = self:Analyze(allPai,iType,resultType);
				allPai[iType][index] = allPai[iType][index] + 1;
				allPai[iType][index+2] = allPai[iType][index+2] + 1;
				allPai[iType][10] = allPai[iType][10] + 2;
				if result then
					resultType.chiType[resultType.iChiNum+1].iType = iType;
					resultType.chiType[resultType.iChiNum+1].iFirstValue = index;
					resultType.iChiNum = resultType.iChiNum + 1;

					return result;
			 	end
			--A B X  /  X A B
			elseif index < 9 and allPai[iType][index+1]>0 then
				allPai[iType][index] = allPai[iType][index] - 1;
				allPai[iType][index+1] = allPai[iType][index+1] - 1;
				allPai[iType][10] = allPai[iType][10] - 2;

				result=self:Analyze(allPai,iType,resultType);

				allPai[iType][index] = allPai[iType][index] + 1;
				allPai[iType][index+1] = allPai[iType][index+1] + 1;
				allPai[iType][10] = allPai[iType][10] + 2;

				if result then
					resultType.chiType[resultType.iChiNum+1].iFirstValue = index;
					resultType.chiType[resultType.iChiNum+1].iType = iType;
					resultType.iChiNum = resultType.iChiNum + 1;

					return result;
				end
			end

			--A X X
			--如果有一张有效牌 和两个会牌 可以组成3刻 或者连
			if index <= 9 and allPai[iType][index] == 1 and resultType.iHuiNum > 0 then

				resultType.iHuiNum = resultType.iHuiNum - 1

				allPai[iType][index] = allPai[iType][index] - 1;
				allPai[iType][10] = allPai[iType][10] - 1;

				result = self:Analyze(allPai,iType,resultType);

				allPai[iType][index] = allPai[iType][index] + 1;
				allPai[iType][10] = allPai[iType][10] + 1;

				if result then
					resultType.chiType[resultType.iChiNum+1].iFirstValue = index;
					resultType.chiType[resultType.iChiNum+1].iType = iType;
					resultType.iChiNum = resultType.iChiNum + 1;

					return result;
				end
				resultType.iHuiNum = resultType.iHuiNum + 1
			end
			resultType.iHuiNum = resultType.iHuiNum + 1
		end
	end

	--检查 将牌（对儿）
	if not resultType.bJiangOK then
		local iNum = 0
		if allPai[iType][index] >= 2 then
			iNum = 2;
		else
			if resultType.iHuiNum > 0 then
				iNum = 1
				resultType.iHuiNum = resultType.iHuiNum - 1;
			else
				return false
			end
		end
		resultType.bJiangOK = true;

		allPai[iType][index] = allPai[iType][index] - iNum;
		allPai[iType][10] = allPai[iType][10] - iNum;

		result=self:Analyze(allPai,iType,resultType);

		allPai[iType][index] = allPai[iType][index] + iNum;
		allPai[iType][10] = allPai[iType][10] + iNum;
		
		if result then
			resultType.jiangType.iType = iType;
			resultType.jiangType.iValue = index;
			
			return result;
		end
		--如果没有凑成对儿,那么将会牌+1
		if allPai[iType][index] < 2 then
			resultType.iHuiNum = resultType.iHuiNum + 1;
		end

		resultType.bJiangOK = false;
	--检查带会牌的碰
	elseif resultType.iHuiNum > 0 and allPai[iType][index] >= 2 then
		resultType.iHuiNum = resultType.iHuiNum - 1;

		allPai[iType][index] = allPai[iType][index] - 2;
		allPai[iType][10] = allPai[iType][10] - 2;

		result = self:Analyze(allPai,iType,resultType);

		allPai[iType][index] = allPai[iType][index] + 2;
		allPai[iType][10] = allPai[iType][10] + 2;

		if result then
			resultType.pengType[resultType.iPengNum+1].iType = iType;
			resultType.pengType[resultType.iPengNum+1].iValue = index;
			resultType.iPengNum = resultType.iPengNum + 1;

			return result;
		end

		resultType.iHuiNum = resultType.iHuiNum + 1;
	--如果有两张会牌
	elseif resultType.iHuiNum >= 2 then
		resultType.iHuiNum = resultType.iHuiNum - 2;

		allPai[iType][index] = allPai[iType][index] - 1;
		allPai[iType][10] = allPai[iType][10] - 1;

		result = self:Analyze(allPai,iType,resultType);

		allPai[iType][index] = allPai[iType][index] + 1;
		allPai[iType][10] = allPai[iType][10] + 1;

		if result then
			resultType.pengType[resultType.iPengNum+1].iType = iType;
			resultType.pengType[resultType.iPengNum+1].iValue = index;
			resultType.iPengNum = resultType.iPengNum + 1;

			return result;
		end

		resultType.iHuiNum = resultType.iHuiNum + 2;
	end


	return false;
end

return judgecard


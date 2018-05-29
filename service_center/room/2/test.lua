


math.randomseed(os.time())

for i = 0, 1000000 do 
 	local aa = math.floor(math.random(100) % 3  + 1 )
 	-- if aa == 0 then
 		print("aa == ", aa)
 	-- end

end



-- local judgeCard = require("judgeCard")


-- local arr_card = {3, 3, 3, 4, 4, 4, 5, 5, 5, 7, 8, 7}
-- local arg_value = 0

-- local bHu = judgeCard:JudgeCardShape(arr_card, 5, arg_value)

-- print(string.format("bHu = [%d], arg_value = [%d]", bHu, arg_value))


-- local bHandThreeCard = false;

-- for i = 1, 20 do 
-- 	while(1) do 
-- 		if(cCards[i] == nil or cCards[i] == 0)continue;
			
-- 	end
-- end


			-- bool  bHandThreeCard = false;
			-- // 检测三张的并且保存出来
			-- for(int i = 0; i < 20; i++)
			-- {
			-- 	if(cCards[i] == 0)continue;
			-- 	for(int j = 0; j < 20; j++)
			-- 	{
			-- 		if(cTempCard[j] == cCards[i])continue;
			-- 	}
			-- 	int iHandCardNums = 1;
			-- 	for(int j = i+1; j < 20; j++)
			-- 	{
			-- 		if(cCards[i] == cCards[j])
			-- 		{
			-- 			iHandCardNums++;
			-- 		}
			-- 		if(iHandCardNums == 3)
			-- 		{
			-- 			bHandThreeCard = true;
			-- 			for(int k = 0; k < 20 ; k++)
			-- 			{
			-- 				if(cTempCard[k] == 0)
			-- 				{
			-- 					cTempCard[k] = cCards[i];
			-- 					cTempCard[k+1] = cCards[i];
			-- 					cTempCard[k+2] = cCards[i];
			-- 					break;
			-- 				}
			-- 			}
			-- 			break;
			-- 		}
			-- 	}
			-- }

			-- // 检测是否有不连续的， 如果是不连续的， 处理掉

			-- for(int i = 0; i < 20; i++)
			-- {
			-- 	if(cTempCard[i] == 0)continue;
			-- 	bool bCheck = false;
			-- 	bool bFindOther = false;

			-- 	if((cTempCard[i] & 0x1f) == 1)
			-- 	{
			-- 		cTempCard[i] = 14;
			-- 	}

			-- 	if((cTempCard[i] & 0x1f) == 2)
			-- 	{
			-- 		cTempCard[i] = 20;
			-- 	}

			-- 	for(int j = 0; j < 20; j++)
			-- 	{
			-- 		if(cTempCard[j] == 0)continue;
			-- 		bFindOther = true;
			-- 		if(cTempCard[i] == cTempCard[j]+1 || cTempCard[i] == cTempCard[j]- 1)
			-- 		{
			-- 			bCheck = true;
			-- 			break;
			-- 		}
			-- 	}
			-- 	// 如果这个牌不是连续的，并且还有其他的三张，证明这个是被带得牌
			-- 	if(bCheck == false && bFindOther)
			-- 	{
			-- 		for(int j = i + 1; j < 20; j++)
			-- 		{
			-- 			if(cTempCard[i] == cTempCard[j])
			-- 			{
			-- 				cTempCard[j] = 0;  //清空掉
			-- 			}
			-- 		}
			-- 		cTempCard[i] = 0;
			-- 	}
			-- }

			-- // 如果没有找到有三张的牌， 这个时候就用传过来的牌值去判断值
			-- if(!bHandThreeCard)
			-- {
			-- 	bLastCard = false;
			-- }



-- （1）求从数组a[1..n]中任选m个元素的所有组合。
-- （2）a[1..n]表示候选集，n为候选集大小，n>=m>0。
-- （3）b[1..M]用来存储当前组合中的元素(这里存储的是元素下标)，
-- -- （4）常量M表示满足条件的一个组合中元素的个数，M=m，这两个参数仅用来输出结果。
-- function combine( a, n, m, b, M )
	
-- 	for i = n, m, -1 do 
-- 		b[m-1] = i - 1
-- 		if m > 1 then
-- 			combine(a,i-1,m-1,b,M);  
-- 		else 				-- m == 1, 输出一个组合  
-- 			-- for(int j=M-1; j>=0; j--)  
-- 			for j = M-1, 0, -1 do 
-- 				print(string.format("a[b[%d] = %d]\n", j, a[b[j]]))
-- 			end
-- 		end
-- 	end
-- end

-- local N = 4;  
-- local a = {}  

-- for i = 1, N, do 
--     a[i] = i+1;  
-- end

-- for(int M = 1; M <= 4; M++)  
-- {  
--     int b[M];  
--     combine(a,N,M,b,M);  
-- }

local judgeCard = require("judgeCard")


local arr_card = {3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 8, 8}
local arg_value = 0

local bHu = judgeCard:JudgeCardShape(arr_card, 5, arg_value)

print(string.format("bHu = [%d], arg_value = [%d]", bHu, arg_value))

local bHandThreeCard = false;

-- for i = 1, 20 do 
-- 	while(1) do 
-- 		if(cCards[i] == nil or cCards[i] == 0)continue;
			
-- 	end
-- end


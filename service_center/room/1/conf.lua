local MJ_CARDS_TYPE = {
	[1] = "🀇",
	[2] = "🀈",
	[3] = "🀉",
	[4] = "🀊",
	[5] = "🀋",
	[6] = "🀌",
	[7] = "🀍",
	[8] = "🀎",
	[9] = "🀏",

	[11] = "🀐",
	[12] = "🀑",
	[13] = "🀒",
	[14] = "🀓",
	[15] = "🀔",
	[16] = "🀕",
	[17] = "🀖",
	[18] = "🀗",
	[19] = "🀘",

	[21] = "🀙",
	[22] = "🀚",
	[23] = "🀛",
	[24] = "🀜",
	[25] = "🀝",
	[26] = "🀞",
	[27] = "🀟",
	[28] = "🀠",
	[29] = "🀡",

	[31] = "🀁",
	[32] = "🀂",
	[33] = "🀃",
	[34] = "🀅",
	[35] = "🀄",
	[36] = "🀆"
}

local card_list = {}

for i=1,30 do
	if i % 10 ~= 0 then
		card_list[i] = 4
	end
end
card_list[35] = 4

local handle1 = {1,2,3,4,4,4,4,5,5,5,6,6,6}
local handle2 = {11,12,13,14,14,14,14,15,15,15,16,16,16}

local utils = require "utils"
local pool = utils:mergeNewTable(handle1,handle2)

for _,value in ipairs(pool) do
	local num = card_list[value]
	card_list[value] = num - 1
end

math.randomseed(tostring(os.time()):reverse():sub(1, 6))
local temp_list = {}

for k,v in pairs(card_list) do
	if v ~= 0 then
		for i=1,v do
			table.insert(temp_list,k)
		end
	end
end

for i=1,#temp_list do
	local value = math.random(1,#temp_list)
	table.insert(pool,value)
end
 

for i,v in ipairs(pool) do
	print(i,v)
end
return {pool=pool,zpos = 1}
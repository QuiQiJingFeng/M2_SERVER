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
			
local handle1 = {4,5,6,7,8,9,23,24,25,26,27,29,29}
local handle2 = {1,2,3,11,12,13,14,15,16,17,18,28,28}

for i,v in ipairs(handle2) do
	table.insert(handle1,v)
end
local pool = handle1

table.insert(pool,28) -- 第一个人摸了个 28  
-->第一个人出28
--第二个人碰 并且出牌18
table.insert(pool,27) -- 第一个人又摸了个27 --》 出牌27
table.insert(pool,28) -- 第二个人摸了个28  这个时候第二个人可以碰杠
--第二个人碰杠
--这个时候第一个人可以抢杠胡


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
	local idx = math.random(1,#temp_list)
	local value = table.remove(temp_list,idx)

	table.insert(pool,value)
end
 

for i,v in ipairs(pool) do
	print(i,v)
end
return {pool=pool,zpos = 1}
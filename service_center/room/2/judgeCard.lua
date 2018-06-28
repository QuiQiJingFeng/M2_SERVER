local JudgeCard  = {}
-- local bit = require ("app.scenes.bit")
-- local bit = require("bit")

JudgeCard.TYPE_SINGLE_CARDS 				= 101			--单牌	  
JudgeCard.TYPE_PAIR_CARDS 					= 102			--对子	
JudgeCard.TYPE_TRIAD_CARDS 					= 103			--三张牌	
JudgeCard.TYPE_TRIAD_CARDS_SINGLE 			= 104			--三带一	
JudgeCard.TYPE_TRIAD_CARDS_PAIR 			= 105			--三带二	

JudgeCard.TYPE_SINGLE_SEQUENCE_CARDS   		= 111 			--	单顺牌(5张)
JudgeCard.TYPE_SINGLE_SEQUENCE_SIX			= 112 			--	单顺牌(6张)
JudgeCard.TYPE_SINGLE_SEQUENCE_SEVEN		= 113 			--	单顺牌(7张)
JudgeCard.TYPE_SINGLE_SEQUENCE_EIGHT		= 114 			--	单顺牌(8张)
JudgeCard.TYPE_SINGLE_SEQUENCE_NINE			= 115 			--	单顺牌(9张)
JudgeCard.TYPE_SINGLE_SEQUENCE_TEN			= 116 			--	单顺牌(10张)
JudgeCard.TYPE_SINGLE_SEQUENCE_ELEVEN		= 117 			--	单顺牌(11张)
JudgeCard.TYPE_SINGLE_SEQUENCE_TWELVE		= 118 			--	单顺牌(12张)

JudgeCard.TYPE_PAIR_SEQUENCE_CARDS			= 121 			--	双顺牌(3对)
JudgeCard.TYPE_PAIR_SEQUENCE_FOUR			= 122 			--	双顺牌(4对)
JudgeCard.TYPE_PAIR_SEQUENCE_FIVE			= 123 			--	双顺牌(5对)
JudgeCard.TYPE_PAIR_SEQUENCE_SIX			= 124 			--	双顺牌(6对)
JudgeCard.TYPE_PAIR_SEQUENCE_SEVEN			= 125 			--	双顺牌(7对)
JudgeCard.TYPE_PAIR_SEQUENCE_EIGHT			= 126 			--	双顺牌(8对)
JudgeCard.TYPE_PAIR_SEQUENCE_NINE			= 127 			--	双顺牌(9对)
JudgeCard.TYPE_PAIR_SEQUENCE_TEN			= 128 			--	双顺牌(10对)

JudgeCard.TYPE_TRIAD_SEQUENCE_CARDS			= 131 			--	三顺牌(连续2个)
JudgeCard.TYPE_TRIAD_SEQUENCE_THREE			= 132 			--	三顺牌(连续3个)
JudgeCard.TYPE_TRIAD_SEQUENCE_FOUR			= 133 			--	三顺牌(连续4个)
JudgeCard.TYPE_TRIAD_SEQUENCE_FIVE			= 134 			--	三顺牌(连续5个)
JudgeCard.TYPE_TRIAD_SEQUENCE_SIX			= 135 			--	三顺牌(连续6个)

JudgeCard.TYPE_FOUR_WITH_SINGLE				= 141 			--	四带二单
JudgeCard.TYPE_FOUR_WITH_PAIR				= 142 			--	四带2对

JudgeCard.TYPE_PLANE_TWO_WING_SIGLE			= 151 			--	飞机带翅膀(两三条带两单牌)
JudgeCard.TYPE_PLANE_TWO_WING_TWO			= 152 			--	飞机带翅膀(两三条带两对子)
JudgeCard.TYPE_PLANE_THREE_WING_SIGLE		= 153 			--	飞机带翅膀(三三条带三单牌)
JudgeCard.TYPE_PLANE_THREE_WING_TWO			= 154 			--	飞机带翅膀(三三条带三对子)
JudgeCard.TYPE_PLANE_FOUR_WING_SIGLE		= 155 			--	飞机带翅膀(四三条带四单牌)
JudgeCard.TYPE_PLANE_FOUR_WING_TWO			= 156 			--	飞机带翅膀(四三条带四对子)
JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE		= 157 			--	飞机带翅膀(五三条带五单牌)

JudgeCard.TYPE_BOMB_CARD					= 161 			--	炸弹
JudgeCard.TYPE_ROCKET_CARD					= 162 			--	火箭

JudgeCard.LITTLE_JOKCER = 24
JudgeCard.BIG_JOKCER = 25

-- int JudgeCardShape(int arg_card[], int arg_num, int &arg_value);

function JudgeCard:JockerSwitch( jocker )
	--  忽略
	return jocker % 100
end

function JudgeCard:JudgeCardShape( arg_card,  arg_num, arg_value)
	if arg_num <= 0  then
		print("ERROR:DDZ.JudgeCard, arg_num = ", arg_num)
		return -1, -1
	end

	-- local card = clone(arg_card)
	local card = {}
	for i , v in pairs(arg_card) do 
		card[i] = self:JockerSwitch(v)
	end

	table.sort(card, function(a, b)
		return a < b
	end)

	-- for i ,v  in pairs(card) do 
	-- 	print(string.format("i = [%d], v = [%d]", i, v))
	-- end

	local statu = 1
	local more_statu = 0
	local i = 2
	local temp_count = 1
	local max_count = 1
	arg_value = card[1]

	-- &: 按位与
	-- |: 按位或
	-- ~: 按位异或
	-- >>: 右移
	-- <<: 左移
	-- ~: 按位非
	if #card > 1 then
		while card[i] ~= nil and i < 17 do
			if card[i] == card[i-1] then
				statu = statu | (3 << (i-1)*2)
				-- statu = bit:_or(statu, bit:_lshift(3, (i-1)*2))
				temp_count = temp_count +1
			elseif card[i] == (card[i-1] + 1) then
				-- print(string.format("card[%d] = [%d], card[i-1] = %d", i, card[i], card[i-1]))
				statu = statu | (2 << (i-1)*2)
				-- statu = bit:_or(statu, bit:_lshift(2, (i-1)*2))
				temp_count = 1
			else
				statu = statu | (1 << (i-1)*2)
				-- statu = bit:_or(statu, bit:_lshift(1, (i-1)*2))
				temp_count = 1
			end

			if (temp_count >= max_count) then
				max_count = temp_count;
				arg_value = card[i];
			end
			i = i + 1
		end

	    if i == 17 then 
	        while i < 21 and card[i] and card[i] ~= -1 and card[i] ~= 0 do 
	            if card[i] == card[i-1]  then 
	                statu = statu | (3 << (i+1 - 17)*2)
	                -- more_statu = bit:_or(statu, bit:_lshift(3, (i+1 - 17)*2))
	                temp_count = temp_count + 1
	            elseif card[i] + 1 == card[i-1] then 
	                statu = statu | (2 << (i+1 - 17)*2)
	                -- more_statu = bit:_or(statu, bit:_lshift(2, (i+1 - 17)*2))
	                temp_count = 1
	            else 
	            	statu = statu | (1 << (i+1 - 17)*2)
	                -- more_statu = bit:_or(statu, bit:_lshift(1, (i+1 - 17)*2))
	                temp_count = 1
	            end 
	          
	            if temp_count > max_count then 
	                max_count = temp_count
	            end  
	            i = i + 1
	        end 
	    end 
	end

	print(string.format("statu = %d ,i = %d max_count = %d arg_value = [%d]", statu, i, max_count, arg_value))

	if more_statu ~= 0 then
		-- more 先不管
		local ret = self:MoreCard(statu, more_statu, arg_value)
        if ret == -1 then 
            arg_value = 0
            return ret ,arg_value
        end 
        return -1 ,arg_value
	else
		if statu == 1 then
			return JudgeCard.TYPE_SINGLE_CARDS, arg_value
		elseif statu == 9 then
			if card[1] == JudgeCard.LITTLE_JOKCER then
				return JudgeCard.TYPE_ROCKET_CARD, arg_value
			end
		elseif statu == 13 then
			return JudgeCard.TYPE_PAIR_CARDS, arg_value
		elseif statu == 61 then
			return JudgeCard.TYPE_TRIAD_CARDS, arg_value
		elseif statu == 253 then
			return JudgeCard.TYPE_BOMB_CARD, arg_value
		elseif statu == 125 or statu == 189 or statu == 249 or statu == 245 then
			return JudgeCard.TYPE_TRIAD_CARDS_SINGLE, arg_value-------三带一---------
		elseif statu == 989 or statu == 1005 or statu == 957 or statu == 893 then
			return JudgeCard.TYPE_TRIAD_CARDS_PAIR , arg_value -- ------三带二------
		elseif statu == 681 then----顺子(五张用及以上数值相邻的单牌)----
			return JudgeCard.TYPE_SINGLE_SEQUENCE_CARDS, arg_value	-- 5张
		elseif statu == 2729 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_SIX, arg_value
		elseif statu == 10921 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_SEVEN, arg_value
		elseif statu == 43689 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_EIGHT, arg_value
		elseif statu == 174761 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_NINE, arg_value
		elseif statu == 699049 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_TEN, arg_value
		elseif statu == 2796201 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_ELEVEN, arg_value
		elseif statu == 11184809 then
			return JudgeCard.TYPE_SINGLE_SEQUENCE_TWELVE, arg_value
		elseif statu == 4029 then ---三顺(两个及以上数值相邻的三条)---
			return JudgeCard.TYPE_TRIAD_SEQUENCE_CARDS, arg_value
		elseif statu == 257981 then 
			return JudgeCard.TYPE_TRIAD_SEQUENCE_THREE, arg_value
		elseif statu == 16510909 then
			return JudgeCard.TYPE_TRIAD_SEQUENCE_FOUR, arg_value
		elseif statu == 1056698301 then 
			return JudgeCard.TYPE_TRIAD_SEQUENCE_FIVE, arg_value
		elseif statu == 3821 then ---双顺(三个及以上数值相邻的对子)---
			return JudgeCard.TYPE_PAIR_SEQUENCE_CARDS, arg_value
		elseif statu == 61165 then
			return JudgeCard.TYPE_PAIR_SEQUENCE_FOUR, arg_value
		elseif statu == 978669 then
			return JudgeCard.TYPE_PAIR_SEQUENCE_FIVE, arg_value
		elseif statu == 15658733 then
			return JudgeCard.TYPE_PAIR_SEQUENCE_SIX, arg_value
		elseif statu == 250539757 then
			return JudgeCard.TYPE_PAIR_SEQUENCE_SEVEN, arg_value
		elseif statu == -286331155 then
			return JudgeCard.TYPE_PAIR_SEQUENCE_EIGHT, arg_value
		----------------四带二--------------
		elseif statu == 4053 or statu == 4057 or statu == 4069 or statu == 4073 or statu == 3065 or statu == 3061 or statu == 2041 or statu == 2557 or statu == 1533 or statu == 2037 or statu == 1789 or statu == 2813 then 
			return JudgeCard.TYPE_FOUR_WITH_SINGLE, arg_value
		----------------四带一个对子----------------
		elseif statu == 61181 or statu == 57085 or statu == 60925 or statu == 56829 or statu == 65261 or statu == 65245 or statu == 65005 or statu == 64989 or statu == 61421 or statu == 61405 or statu == 57325 or statu == 57309  then 
			return JudgeCard.TYPE_FOUR_WITH_PAIR, arg_value

		----------------两个相邻三条带两张单牌--------------
		elseif statu == 64469 or statu == 64473 or statu == 64485 or statu == 64489 or statu == 24509 or statu == 40893 or statu == 28605 or statu == 44989 or statu == 48885 or statu == 48889 or statu == 32505 or statu == 32501 then
			return JudgeCard.TYPE_PLANE_TWO_WING_SIGLE, arg_value
		----------------两个相邻三条带两对子--------------
		elseif statu == 909245 or statu == 913341 or statu == 916445 or statu == 916461 or statu == 974781 or statu == 978877 or statu == 981981 or statu == 981997 or statu == 1031645 or statu == 1031661 or statu == 1031901 or statu == 1031917 then
			return JudgeCard.TYPE_PLANE_TWO_WING_TWO, arg_value
		----------------三个相邻三条带三张单牌--------------
		elseif statu == 5763005 or statu == 6025149 or statu == 6274805 or statu == 6274809 or statu == 6811581 or statu == 7073725 or statu == 7323381 or statu == 7323385 or statu == 8322005 or statu == 8322009 or statu == 8322021 or statu == 8322025 or statu == 9957309 or statu == 10219453 or statu == 10469109 or statu == 10469113 or statu == 11005885 or statu == 11268029 or statu == 11517685 or statu == 11517689 or statu == 12516309 or statu == 12516313 or statu == 12516325 or statu == 12516329 or statu == 16510805 or statu == 16510809 or statu == 16510821 or statu == 16510825 or statu == 16510869 or statu == 16510873 or statu == 16510885 or statu == 16510889  then
			return JudgeCard.TYPE_PLANE_THREE_WING_SIGLE, arg_value
		----------------三个相邻三条带三对子--------------
		elseif  statu == 930607037 or statu == 930869181 or statu == 931068893 or statu == 931068909 or statu == 934801341 or statu == 935063485 or statu == 935263197 or statu == 935263213 or statu == 938458589 or statu == 938458605 or statu == 938458845 or statu == 938458861 or statu == 997715901 or statu == 997978045 or statu == 998177757 or statu == 998177773 or statu == 1001910205 or statu == 1002172349 or statu == 1002372061 or statu == 1002372077 or statu == 1005567453 or statu == 1005567469 or statu == 1005567709 or statu == 1005567725 or statu == 1056693725 or statu == 1056693741 or statu == 1056693981 or statu == 1056693997 or statu == 1056697821 or statu == 1056697837 or statu == 1056698077 or statu == 1056698093 then 
			return JudgeCard.TYPE_PLANE_THREE_WING_TWO, arg_value
		----------------四个相邻三条带四张单牌--------------
		elseif statu == -1778651203 or statu == -1761873987 or statu == -1745895691 or statu == -1745895687 or statu == -1711542339 or statu == -1694765123 or statu == -1678786827 or statu == -1678786823 or statu == -1614873643 or statu == -1614873639 or statu == -1614873627 or statu == -1614873623 or statu == -1510215747 or statu == -1493438531 or statu == -1477460235 or statu == -1477460231 or statu == -1443106883 or statu == -1426329667 or statu == -1410351371 or statu == -1410351367 or statu == -1346438187 or statu == -1346438183 or statu == -1346438171 or statu == -1346438167 or statu == -1090785451 or statu == -1090785447 or statu == -1090785435 or statu == -1090785431 or statu == -1090785387 or statu == -1090785383 or statu == -1090785371 or statu == -1090785367 or statu == -68174507 or statu == -68174503 or statu == -68174491 or statu == -68174487 or statu == -68174443 or statu == -68174439 or statu == -68174427 or statu == -68174423 or statu == -68174251 or statu == -68174247 or statu == -68174235 or statu == -68174231 or statu == -68174187 or statu == -68174183 or statu == -68174171 or statu == -68174167 or statu == 1442574269 or statu == 1459351485 or statu == 1475329781 or statu == 1475329785 or statu == 1509683133 or statu == 1526460349 or statu == 1542438645 or statu == 1542438649 or statu == 1606351829 or statu == 1606351833 or statu == 1606351845 or statu == 1606351849 or statu == 1711009725 or statu == 1727786941 or statu == 1743765237 or statu == 1743765241 or statu == 1778118589 or statu == 1794895805 or statu == 1810874101 or statu == 1810874105 or statu == 1874787285 or statu == 1874787289 or statu == 1874787301 or statu == 1874787305 or statu == 2130440021 or statu == 2130440025 or statu == 2130440037 or statu == 2130440041 or statu == 2130440085 or statu == 2130440089 or statu == 2130440101 or statu == 2130440105  then

			-- 4009488317

			return JudgeCard.TYPE_PLANE_FOUR_WING_SIGLE, arg_value
		end
	end


	arg_value = 0
	return -1, arg_value
end


function JudgeCard:MoreCard(arg_low, arg_high, arg_value)

    if  arg_high == 1004  then 
        if arg_low == 4022202093 then 
            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO, arg_value 
        end
    elseif arg_high == 680  then 
        if arg_low ==3204181949 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value 
        end  
    elseif arg_high == -107 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -106 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -105 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == 272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -103 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -102 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
        return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -101 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -97 then 
        if arg_low == -1090785451 or arg_low == -1090785447 or arg_low == - 1090785435 or arg_low  == -1090785431
            or arg_low == - 1090785387 or arg_low  == -1090785383 or arg_low == - 1090785371 or arg_low  == -1090785367 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -91 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  ==2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -90 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  ==2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -89 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == -272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -87 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -86 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -85 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == -272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -81 then 
        if arg_low == -1090785451 or arg_low == -1090785447 or arg_low == - 1090785435 or arg_low  == -1090785431
            or arg_low == - 1090785387 or arg_low  == -1090785383 or arg_low == - 1090785371 or arg_low  == -1090785367 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == -66 then 
        if arg_low == -68174503 or arg_low == -68174491 or arg_low == -68174487 or arg_low  == -68174443
            or arg_low == -68174439 or arg_low  == -68174427 or arg_low == -68174423 or arg_low  == -68174251 
            or arg_low == -68174247 or arg_low  == -68174235 or arg_low == -68174231 or arg_low  == -68174187
            or arg_low == -68174183 or arg_low  == -68174171 or arg_low == -68174167 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 85 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == -68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 86 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 87 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 89 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 90 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 91 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 95 then 
        if arg_low == -1090785451 or arg_low == -1090785447 or arg_low == - 1090785435 or arg_low  == -1090785431
            or arg_low == - 1090785387 or arg_low  == -1090785383 or arg_low == - 1090785371 or arg_low  == -1090785367 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 101 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == -2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 102 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 103 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 105 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 106 then 
        if arg_low == -1090785347 or arg_low == -68174091 or arg_low == - 68174087 or arg_low  == 2130440125 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 107 then 
        if arg_low == -272696363 or arg_low == -272696359 or arg_low == - 272696347 or arg_low  == -272696343 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 111 then 
        if arg_low == -1090785451 or arg_low == -1090785447 or arg_low == - 1090785435 or arg_low  == -1090785431
            or arg_low == - 1090785387 or arg_low  == -1090785383 or arg_low == - 1090785371 or arg_low  == -1090785367 then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end
    elseif arg_high == 126 then 
        if arg_low == -68174503 or arg_low == -68174491 
            or arg_low == - 68174487 or arg_low  == -68174443
            or arg_low == - 68174439 or arg_low  == -68174427
            or arg_low == - 68174423 or arg_low  == -68174251 
            or arg_low == - 68174247 or arg_low  == -68174235
            or arg_low == - 68174231 or arg_low  == -68174187
            or arg_low == - 68174183 or arg_low  == -68174171 
            or arg_low == - 68174167
            then 
            return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end 
    elseif arg_high == -5  then 
        if arg_low == -272697943 or arg_low == -272697751 
            or arg_low == - 272697703 or arg_low  == -272697691
            or arg_low == - 272697687 or arg_low  == -272696983
            or arg_low == - 272696935 or arg_low  == -272696923 
            or arg_low == - 272696919 or arg_low  == -272696743
            or arg_low == - 272696731 or arg_low  == -272696727
            or arg_low == - 272696683 or arg_low  == -272696679 
            or arg_low == - 272696667 or arg_low  == -272696663 then
                return JudgeCard.TYPE_PLANE_FIVE_WING_SIGLE,arg_value
        end  

        if arg_low == -272769571 or arg_low == -272769555 
            or arg_low == - 272769315 or arg_low  == -272769299
            or arg_low == - 272765475 or arg_low  == -272765459 
            or arg_low == - 272765459 or arg_low  == -272765219
            or arg_low == - 272765203 or arg_low  == -272704035
            or arg_low == - 272704019 or arg_low  == -272703779 
            or arg_low == - 272703763 or arg_low  == -272699939 
            or arg_low == - 272699923 or arg_low  == -272699683 
            or arg_low == - 272699667 then 
            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end  
    elseif arg_high == -35  then
        if arg_low == -570691651 or arg_low  == -553914435
            or arg_low == -541131811 or arg_low  == -541131795 
            or arg_low == -302256195 or arg_low  == -285478979 
            or arg_low == -272696355 or arg_low  == -272696339 
            or arg_low == -68174371 or arg_low  == -68174355 
            or arg_low == -68174115 or arg_low  == -68174099 then 

            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value 
        end 
    elseif  arg_high == -34  then 
        if arg_low == -570691651 or arg_low  == -553914435
            or arg_low == -541131811 or arg_low  == -541131795 
            or arg_low == -302256195 or arg_low  == -285478979 
            or arg_low == -272696355 or arg_low  == -272696339
            or arg_low == -68174371 or arg_low  == -68174355 
            or arg_low == -68174115 or arg_low  == -68174099 then
                  
            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end  
    elseif  arg_high == -33  then 
        if arg_low == -1090789923 or arg_low  == -1090789907
            or arg_low == -1090789667 or arg_low  == -1090789651 
            or arg_low == -1090785827 or arg_low  == -1090785811 
            or arg_low == -1090785571 or arg_low  == -1090785555  then 

            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end 
    elseif arg_high == -19  then 
        if arg_low == -570691651 or arg_low  == -553914435
            or arg_low == -541131811 or arg_low  == -541131795 
            or arg_low == -302256195 or arg_low  == -285478979 
            or arg_low == -272696355 or arg_low  == -272696339  
            or arg_low == -68174371 or arg_low  == -68174355 
            or arg_low == -68174115 or arg_low  == -68174099 then 

            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end 
    elseif arg_high == -17  then 
        if arg_low == -1090789923 or arg_low  == -1090789907
            or arg_low == -1090789667 or arg_low  == -1090789651 
            or arg_low == -1090785827 or arg_low  == -1090785811 
            or arg_low == -1090785571 or arg_low  == -1090785555 then 

            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end 

    elseif  arg_high == -18  then 
        if arg_low == -570691651 or arg_low  == -553914435
            or arg_low == -541131811 or arg_low  == -541131795 
            or arg_low == -302256195 or arg_low  == -285478979 
            or arg_low == -272696355 or arg_low  == -272696339  
            or arg_low == -68174371 or arg_low  == -68174355 
            or arg_low == -68174115 or arg_low  == -68174099 then 

            return JudgeCard.TYPE_PLANE_FOUR_WING_TWO,arg_value
        end 
        
        if arg_low == -286331155 then 
            return JudgeCard.TYPE_PAIR_SEQUENCE_TEN,arg_value
        end 
    elseif arg_high == 56 then 
        if arg_low == 4008636141 then 
            return JudgeCard.TYPE_PAIR_SEQUENCE_NINE,arg_value   --9˳
        end
    elseif arg_high == 952 then 
        if arg_low == 4008636141 then 
            return JudgeCard.TYPE_PAIR_SEQUENCE_TEN,arg_value   --10˳
        end  
    elseif arg_high == 60 then 
        if arg_low == 3204181949 then 
            return JudgeCard.TYPE_TRIAD_SEQUENCE_SIX,arg_value
        end 
    end 
end



return JudgeCard
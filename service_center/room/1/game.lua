local skynet = require "skynet"
local utils = require "utils"
local constant = require "constant"
local cjson = require "cjson"
local judgecard = require "judgecard"
local ALL_CARDS = constant.ALL_CARDS
local ALL_ZJ_MODE = constant.ALL_ZJ_MODE
local ROUND_COST = constant.ROUND_COST
local PAY_TYPE = constant.PAY_TYPE
local TYPE = {
	CHI = 1,
	PENG = 2,
	PENG_GANG = 3,
	MING_GANG = 4,
	AN_GANG = 5,
	HU = 6
}
local game = {}
local game_meta = {}
setmetatable(game,game_meta)
game.__index = game_meta
game.__newindex = game_meta

local GAME_OVER_TYPE = {
	NORMAL = 1, --正常胡牌
	FLOW = 2,	--流局
	DISTROY_ROOM = 3,   --房间解散推送结算积分
}

function game:start(room)
	print("========game start=========")
	self.room = room
	--填充牌库
	self.card_list = {}
	for _,value in ipairs(ALL_CARDS[room.game_type]) do
		table.insert(self.card_list,value)
	end
	--洗牌
	utils:fisherYates(self.card_list)
	--底分
	self.base_score = self.room.other_setting[1]
	--奖码数
	self.award_num = self.room.other_setting[2]
	--七对
	self.seven_pairs = self.room.other_setting[3] == 1
	--喜分
	self.hi_point = self.room.other_setting[4] == 1
	--一码不中当全中
	self.convert = self.room.other_setting[5] == 1
	--等待玩家操作的列表
	self.waite_operators = {}
	--当前出牌人
	self.cur_play_user = nil
	--当前出的牌
	self.cur_play_card = nil
	--胡牌列表
	self.hu_list = {}
	-- 每个玩家出的牌的列表
	self.put_cards = {}
	--玩家当前局积分清零
	for _,player in ipairs(self.room.player_list) do
		player.cur_score = 0
		player.card_stack = {}
		player.handle_cards = {}
	end	

	self:updateZpos()

	if constant["DEBUG"] then
		local conf = require(self.room.game_type.."/conf")
		self.zpos = conf.zpos
		utils:mergeToTable(self.card_list,conf.card_list)
	end

	-- 随机骰子
	local random_nums = {}
	for i = 1,2 do
		local num = math.random(1,6)
		table.insert(random_nums,num)
	end

	--2、发牌
	local deal_num = 13 --红中麻将发13张牌
	for index=1,self.room.seat_num do
		local cards = {}
		for j=1,deal_num do
			--从最后一个开始移除,避免大量的元素位置重排
			local card = table.remove(self.card_list) 
			table.insert(cards,card)
		end

		local player = self.room:getPlayerByPos(index)
		player.card_list = cards
		local rsp_msg = {}
		rsp_msg.zpos = self.zpos
		rsp_msg.cards = cards
		rsp_msg.user_id = user_id
		rsp_msg.user_pos = player.user_pos
		rsp_msg.random_nums = random_nums
		rsp_msg.cur_round = self.room.cur_round
		player:send({deal_card = rsp_msg})
	end

	--3、将card按类别和数字存储
	for _,player in ipairs(self.room.player_list) do
		local card_list = player.card_list
		local handle_cards = { }
		for i= 1,4 do
			handle_cards[i] = {}
			for j= 1,10 do
				handle_cards[i][j] = 0
			end
		end

		for _,value in ipairs(card_list) do
			local card_type = math.floor(value / 10) + 1
			local card_value = value % 10
			handle_cards[card_type][10] = handle_cards[card_type][10] + 1
			handle_cards[card_type][card_value] = handle_cards[card_type][card_value] + 1
		end
		player.handle_cards = handle_cards
	end
	--等待所有玩家发回发牌完毕的命令
	for i,player in ipairs(self.room.player_list) do
		self.waite_operators[player.user_pos] = "WAIT_DEAL_FINISH"
	end
end

--更新庄家的位置
function game:updateZpos(winner_pos)
	if new_pos then
		self.zpos = winner_pos
		return
	end
	local zpos = nil
	local zj_mode = ALL_ZJ_MODE[self.room.game_type]
	if zj_mode == "YING" then
		local seat_num = self.room.seat_num
		if not self.zpos then
			zpos = math.random(1,seat_num)
		else
			zpos = self.zpos
		end
	elseif zj_mode == "LIAN" then
		local seat_num = self.room.seat_num
		if not self.zpos then
			zpos = math.random(1,seat_num)
		else
			zpos = (self.zpos + 1) >= seat_num and 1 or (self.zpos + 1)
		end
	end
	
	self.zpos = zpos
end

--增加手牌
function game:addHandleCard(player,card)
	table.insert(player.card_list,card)
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10

	local handle_cards = player.handle_cards
	handle_cards[card_type][10] = handle_cards[card_type][10] + 1
	handle_cards[card_type][card_value] = handle_cards[card_type][card_value] + 1
end

--减去手牌
function game:removeHandleCard(player,card,num)
	num = num or 1
	local indexs = {}
	for i=#player.card_list,1,-1 do
		local value = player.card_list[i]
		if value == card then
			table.insert(indexs,i)
		end
	end

	if #indexs < num then
		return false
	end

	for i,idx in ipairs(indexs) do
		if i <= num then
			table.remove(player.card_list,idx)
			local card_type = math.floor(card / 10) + 1
			local card_value = card % 10
			local handle_cards = player.handle_cards
			handle_cards[card_type][10] = handle_cards[card_type][10] - 1
			handle_cards[card_type][card_value] = handle_cards[card_type][card_value] - 1
		else
			break
		end
	end
	
	return true
end

--游戏命令
function game:game_cmd(content)
	local user_id = content.user_id
	local command = content.command
	local func = game[command]
	if not func then
		return "no_support_command"
	end
	local player = self.room:getPlayerByUserId(user_id)
	return func(game,player,content)
end

--发牌完毕
game["DEAL_FINISH"] = function(self, player)

	local user_pos = player.user_pos
	if self.waite_operators[user_pos] ~= "WAIT_DEAL_FINISH" then
		return "invaild_operator"
	end
	self.waite_operators[user_pos] = nil
	--计算剩余的数量
	local num = 0
	for k, v in pairs(self.waite_operators) do
		num = num + 1
	end

	if num <= 0 then
		--庄家出牌
		local zplayer = self.room:getPlayerByPos(self.zpos)
		self:drawCard(zplayer)

	end
	return "success"
end

--向A发一张牌 摸牌
function game:drawCard(player)
	--检查是否流局
	local is_flow = self:flowBureau()
	if is_flow then
		self:gameOver(player,GAME_OVER_TYPE.FLOW)
		return 
	end

	local card = table.remove(self.card_list)
	self:addHandleCard(player,card)
	local user_id = player.user_id

	--通知摸牌
	for _,obj in ipairs(self.room.player_list) do
		local data = {user_id = user_id,user_pos = player.user_pos}
		if obj.user_id == user_id then
			data.card = card
		end
		obj:send({push_draw_card = data})
	end

	--通知玩家出牌了
	local operator = 1
	self:noticePushPlayCard(player,operator)

	self.waite_operators[player.user_pos] = "WAIT_PLAY_CARD"
end


--检测流局
function game:flowBureau()
	local num = #self.card_list
	if num  == self.award_num then
		return true
	end

	return false
end

--通知玩家出牌
function game:noticePushPlayCard(splayer,operator)
	local players = self.room.player_list
	for i,player in ipairs(players) do
		local rsp_msg = {user_id=splayer.user_id,user_pos=splayer.user_pos}
		if player.user_id == splayer.user_id then
			rsp_msg.card_list = player.card_list
			rsp_msg.card_stack = player.card_stack
		end
		rsp_msg.operator = operator
		player:send({push_play_card=rsp_msg})
	end
end

--出牌
game["PLAY_CARD"] = function(self,player,data)
	
	if not string.find(self.waite_operators[player.user_pos],"WAIT_PLAY_CARD") then 
		return "invaild_operator" 
	end
	if not data.card then 
		return "paramater_error" 
	end
		
	--减少A玩家的手牌
	local result = self:removeHandleCard(player,data.card)
	if not result then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil

	local user_id = player.user_id
	local data = {user_id = user_id,card = data.card,user_pos = player.user_pos}
	--通知所有人 A 已经出牌
	self.room:broadcastAllPlayers("notice_play_card",data)

	--记录下当前出牌人和当前出的牌
	self.cur_play_user = player
	self.cur_play_card = data.card

	if not self.put_cards[player.user_pos] then
		self.put_cards[player.user_pos] = {}
	end
	table.insert(self.put_cards[player.user_pos],data.card)

	local card_type = math.floor(data.card / 10) + 1
	local card_value = data.card % 10
	--因为红中麻将只能 抢杠胡(碰杠,先碰,然后自摸一个)和自摸胡,所以这里不用判断胡牌
	--只需要判断是否碰、杠 并且有且最多只有一个人会碰、杠
	local num = 0
	local check_player = nil
	local user_pos = player.user_pos
	for pos = user_pos+1,user_pos + self.room.seat_num - 1 do
		if pos > self.room.seat_num then
			pos = 1
		end
		check_player = self.room:getPlayerByPos(pos)
		local handle_cards = check_player.handle_cards
		num = handle_cards[card_type][card_value]
		if num == 2 then
			break
		elseif num == 3 then
			break
		end
	end
	local operator_list = {}
	if num == 2 then  --碰
		table.insert(operator_list,"PENG")
		check_player:send({push_player_operator_state = {operator_list=operator_list,user_pos=check_player.user_pos,card=data.card}})
		self.waite_operators[check_player.user_pos] = "WAIT_PENG"
	elseif num == 3 then  --杠
		table.insert(operator_list,"PENG")
		table.insert(operator_list,"GANG")
		check_player:send({push_player_operator_state={operator_list=operator_list,user_pos=check_player.user_pos,card=data.card}})
		self.waite_operators[check_player.user_pos] = "WAIT_GANG_WAIT_PENG"
	else
		next_pos = user_pos + 1
		if next_pos > self.room.seat_num then
			next_pos = 1
		end
		local next_player = self.room:getPlayerByPos(next_pos)
		self:drawCard(next_player)
	end


	return "success"
end

function game:checkPeng(player,card)
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10
	local handle_cards = player.handle_cards
	return handle_cards[card_type][card_value] >= 2
end

--碰
game["PENG"] = function(self,player,data)
	if not string.find(self.waite_operators[player.user_pos],"WAIT_PENG") then
		return "invaild_operator"
	end
	self.waite_operators[player.user_pos] = nil
	
	local card = self.cur_play_card
	if not self:checkPeng(player,card) then
		return "invaild_operator"
	end

	local obj = {value = card,from = self.cur_play_user.user_pos,type=TYPE.PENG}
	--记录下已经碰的牌
	table.insert(player.card_stack,obj)

	--移除手牌
	local result = self:removeHandleCard(player,card,2)
	if not result then
		return "server_error"
	end

	--通知所有人,有人碰了
	local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}

	self.room:broadcastAllPlayers("notice_special_event",data)

	--通知玩家出牌
	local operator = 2
	self:noticePushPlayCard(player,operator)

	self.waite_operators[player.user_pos] = "WAIT_PLAY_CARD_FROM_PENG"

	return "success"
end

function game:checkGang(player,card)
	--1、暗杠 手牌拥有四张牌				  =>暗杠
	--2、明杠 手牌拥有三张,加上别人出的一张     =>别人放的杠
	--3、碰杠 手牌拥有1张                    =>自己摸的明杠
	local result
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10
	local handle_cards = player.handle_cards
	local num = handle_cards[card_type][card_value]
	if num >= 4 then
		result = TYPE.AN_GANG
	elseif num >= 3 then
		result = TYPE.MING_GANG
	elseif num == 1 then
		for _,obj in ipairs(player.card_stack) do
			if obj.value == card and obj.type == TYPE.PENG then
				result = TYPE.PENG_GANG
				break
			end
		end
	end

	return result
end

--检查是否可以胡牌
function game:checkHu(player)
	local tempResult = {
		iChiNum = 0;	
		iPengNum = 0;		
		iHuiNum = 0;		
		bJiangOK = false;
		iHuiType = 0;	
		chiType = {
			[1] = {iType = 0,iFirstValue = 0,iFromPost = 0},
			[2] = {iType = 0,iFirstValue = 0,iFromPost = 0},
			[3] = {iType = 0,iFirstValue = 0,iFromPost = 0},
			[4] = {iType = 0,iFirstValue = 0,iFromPost = 0},

		};
		pengType = {
			[1] = {iType = 0,iValue = 0,iFromPost = 0},
			[2] = {iType = 0,iValue = 0,iFromPost = 0},
			[3] = {iType = 0,iValue = 0,iFromPost = 0},
			[4] = {iType = 0,iValue = 0,iFromPost = 0},

		};
		jiangType = {
			[1] = {iType = 0,iValue = 0},
			[2] = {iType = 0,iValue = 0},
			[3] = {iType = 0,iValue = 0},
			[4] = {iType = 0,iValue = 0},

		}
	}
	tempResult.iHuiCard = 35
	return judgecard:JudgeIfHu2(player.handle_cards, tempResult, self.seven_pairs),tempResult
end

--杠
game["GANG"] = function(self,player,data)
	local card = data.card
	local gang_type = self:checkGang(player,card)
	if not gang_type then
		return "invaild_operator"
	end

	local operate = self.waite_operators[player.user_pos]

	--如果操作是等待出牌,并且可以进行暗杠,则可以进去
	if string.find(operate,"WAIT_PLAY_CARD") and (gang_type == TYPE.AN_GANG or gang_type == TYPE.PENG_GANG ) then
	elseif not string.find(self.waite_operators[player.user_pos],"WAIT_GANG") then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil

	local obj = {value = card,type=gang_type}
	local num = 0
	if gang_type == TYPE.AN_GANG then
		obj.from = player.user_pos
		num = 4
		--记录下已经杠的牌
		table.insert(player.card_stack,obj)
	elseif gang_type == TYPE.MING_GANG then
		obj.from = self.cur_play_user.user_pos
		num = 3
		--记录下已经杠的牌
		table.insert(player.card_stack,obj)
	elseif gang_type == TYPE.PENG_GANG then
		num = 1
		--如果是碰杠,则更改碰变成杠
		for _,item in ipairs(player.card_stack) do
			if item.value == card and item.type == TYPE.PENG then
				item.type = TYPE.PENG_GANG
				obj = item
				break
			end
		end
	end

	--移除手牌
	local result = self:removeHandleCard(player,card,num)
	if not result then
		return "server_error"
	end

	--通知所有人,有人杠了
	local data = {user_id = player.user_id,user_pos = player.user_pos,item = obj}
	self.room:broadcastAllPlayers("notice_special_event",data)
	local players = self.room.player_list
	local count = self.room.seat_num - 1

	local origin_data = self.room:getPlayerInfo("user_id","cur_score")
	--计算杠的积分
	if obj.type == TYPE.AN_GANG then
		--暗杠，赢每个玩家2*底分；
		player.cur_score = player.cur_score + self.base_score * 2 * count
		for _,obj in ipairs(players) do
			if player.user_id ~= obj.user_id then
				obj.cur_score = obj.cur_score - self.base_score * 2
			end
		end
	elseif obj.type == TYPE.MING_GANG then
		--明杠 赢放杠者3*底分
		player.cur_score = player.cur_score + self.base_score * 3
		for _,obj in ipairs(players) do
			if obj.from == obj.user_pos then
				obj.cur_score = obj.cur_score - self.base_score * 3
			end
		end
	elseif obj.type == TYPE.PENG_GANG then
		--自己摸的明杠(公杠) 三家出，赢每个玩家1*底分；
		player.cur_score = player.cur_score + self.base_score * 1 * count
		for _,obj in ipairs(players) do
			if player.user_id ~= obj.user_id then
				obj.cur_score = obj.cur_score - self.base_score * 1
			end
		end
	end
	local data = self.room:getPlayerInfo("user_id","user_pos","cur_score")
	for _,origin_info in ipairs(origin_data) do
		for _,info in ipairs(data) do
			if origin_info.user_id == info.user_id then
				info.delt_score = info.cur_score - origin_info.cur_score
				info.cur_score = nil
			end
		end
	end

	self.room:broadcastAllPlayers("refresh_player_cur_score",{cur_score_list=data})

	if gang_type ~= TYPE.PENG_GANG then
		--杠了之后再摸一张牌
		self:drawCard(player)
		return "success"
	end

	--如果是碰杠,则需要检查是否有人胡这张牌
	local hu_list = {}
	local players = self.room.player_list
	for _,temp_player in ipairs(players) do
		if temp_player.user_id ~= player.user_id then
			--有红中不能抢杠胡
			local num = temp_player.handle_cards[3][5]
			if num <= 0 then
				--胡牌前,先将这张杠牌加入玩家手牌
				self:addHandleCard(temp_player,card)
				local is_hu = self:checkHu(player)
				--检查完之后,去掉这张牌
				self:removeHandleCard(temp_player,card,1)
				if is_hu then
					table.insert(hu_list,temp_player)
				end
			end
		end
	end

	if #hu_list > 1 then
		self.hu_list = hu_list
		local gang_pos = player.user_pos
		table.sort(hu_list,function(a,b) 
				local a_pos = a.user_pos
				local b_pos = b.user_pos
				if a_pos < gang_pos then
					a_pos = a_pos * 100
				end
				if b_pos < gang_pos then
					b_pos = b_pos * 100
				end
				return a_pos < b_pos
			end)

		local hu_player = table.remove(hu_list,1)
		--通知客户端当前可以胡牌
		hu_player:send({push_player_operator_state={operator_state = "HU",user_pos = hu_player.user_pos,user_id=hu_player.user_id}})
		self.waite_operators[hu_player.user_pos] = "WAIT_HU"
	else
	    --杠了之后再摸一张牌
		self:drawCard(player)
	end

	return "success"
end

--过
game["GUO"] = function(self,player,data)
	local operate = self.waite_operators[player.user_pos]
	if not operate then
		return "invaild_operator"
	end
	self.waite_operators[player.user_pos] = nil

	--检测是否有下一个人胡牌
	if self.hu_list and #self.hu_list >= 1 then
		local hu_player = table.remove(hu_list,1)
		--通知客户端当前可以胡牌
		hu_player:send({push_player_operator_state={operator_state = "HU",user_pos = hu_player.user_pos,user_id=hu_player.user_id}})
		self.waite_operators[hu_player.user_pos] = "WAIT_HU"
	else
		-- 如果某个碰、杠被过了,那么原来的出牌人的下一位摸牌
		local next_pos = self.cur_play_user.user_pos + 1
		if next_pos > self.room.seat_num then
			next_pos = 1
		end
		local next_player = self.room:getPlayerByPos(next_pos)
		self:drawCard(next_player)
	end

	return "success"
end

--胡牌
game["HU"] = function(self,player,data)
	local operate = self.waite_operators[player.user_pos]
	local gang_hu = string.find(self.waite_operators[player.user_pos],"WAIT_HU")

	if not (string.find(operate,"WAIT_PLAY_CARD") or gang_hu) then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil

	--抢杠的话,杠是不算的
	if gang_hu then
		local card = nil
		for _,obj in ipairs(player.card_stack) do
			if obj.type == TYPE.PENG_GANG then
				obj.type = TYPE.PENG
				card = obj.value
			end
		end
		--胡牌前,先将这张杠牌加入玩家手牌
		self:addHandleCard(player,card)
		local is_hu,tempResult = self:checkHu(player)
		--检查完之后,去掉这张牌
		self:removeHandleCard(player,card,1)
		if is_hu then
			self:gameOver(player,GAME_OVER_TYPE.NORMAL,operate,tempResult)
		end
		return "success"
	end

	local is_hu,tempResult = self:checkHu(player)
	if is_hu then
		self:gameOver(player,GAME_OVER_TYPE.NORMAL,operate,tempResult)
	end
	return "success"
end

--更新玩家的积分
function game:updatePlayerScore(player,over_type,operate,tempResult)
	local players = self.room.player_list
	local seat_num = self.room.seat_num
	local award_list = {}
	if over_type == GAME_OVER_TYPE.NORMAL then
		local count = seat_num - 1
		--如果是自摸胡  赢每个玩家2*底分
		if string.find(operate,"WAIT_PLAY_CARD") then
			player.cur_score = player.cur_score + self.base_score * 2 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2
				end
			end
		end

		if self.hi_point then 
			--摸到四张红中胡牌，赢每个玩家2*底分
			if tempResult.iHuiNum == 4 then
				player.cur_score = player.cur_score + self.base_score * 2 * count + 5 * count
				for _,obj in ipairs(players) do
					if player.user_id ~= obj.user_id then
						obj.cur_score = obj.cur_score - self.base_score * 2 - 5
					end
				end
			end
		end

		if self.seven_pairs then
			--胡七对 赢每个玩家2*底分
			if tempResult.iChiNum + tempResult.iPengNum == 0 then
				player.cur_score = player.cur_score + self.base_score * 2 * count
				for _,obj in ipairs(players) do
					if player.user_id ~= obj.user_id then
						obj.cur_score = obj.cur_score - self.base_score * 2
					end
				end
			end
		end

		local award_num = self.award_num
		--每一张码 赢每个玩家2*底分
		if tempResult.iHuiNum == 0 then
			--如果没有红中,则额外奖励两张码
			award_num = award_num + 2
		end

		--奖码列表
		for i=1,award_num do
			local card = self.card_list[i]
			if card then
				table.insert(award_list,card)
			end
		end
		local num = 0
		for _,card in ipairs(award_list) do
			local card_value = card % 10
			--红中的值是35,所以这里就不单独写了
			if card_value == 1 or card_value == 5 or card_value == 9 then
				num = num + 1
			end
		end
		-- 一码不中当全中
		if self.convert and num <= 0 then
			num =  award_num
		end

		if num > 0 then
			player.cur_score = player.cur_score + self.base_score * 2 * num * count 
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2 * num
				end
			end
		end

		--更新玩家的总积分
		for i,obj in ipairs(players) do
			obj.score = obj.score + obj.cur_score
		end
	else
		for _,player in ipairs(players) do
			player.cur_score = 0
		end
	end

	if over_type == GAME_OVER_TYPE.NORMAL then
		player.hu_num = player.hu_num + 1
		player.reward_num = player.reward_num + 1
		for _,player in ipairs(players) do
			for i,obj in ipairs(player.card_stack) do
				if obj.type == TYPE.AN_GANG then
					player.an_gang_num = player.an_gang_num + 1
				elseif obj.type == TYPE.MING_GANG or obj.type == TYPE.PENG_GANG then
					player.ming_gang_num = player.ming_gang_num + 1
				end
			end
			player.card_stack = {}
		end
	end

	local info = self.room:getPlayerInfo("user_id","score","card_list","user_pos","cur_score")
	local data = {over_type = over_type,players = info,award_list=award_list}

	if over_type == GAME_OVER_TYPE.NORMAL then
		data.winner_pos = player.user_pos
		if string.find(operate,"WAIT_PLAY_CARD") then
			data.winner_type = constant["WINNER_TYPE"].ZIMO
		elseif operate == "WAIT_HU" then
			data.winner_type = constant["WINNER_TYPE"].QIANG_GANG
		end
	end
	local cur_round = self.room.cur_round
	local round = self.room.round
	data.last_round = cur_round == round

	self.room:broadcastAllPlayers("notice_game_over",data)
end

--更新玩家的金币
function game:updatePlayerGold(over_type)
	if over_type == GAME_OVER_TYPE.DISTROY_ROOM then
		return 
	end
	local room = self.room
	local players = room.players
	local cur_round = room.cur_round
	local round = room.round
	local seat_num = room.seat_num

	--花费
	local cost = round * ROUND_COST
	--出资类型
	local pay_type = room.pay_type
	--第一局结束 结算(房主出资/平摊出资)的金币
	if cur_round == 1 then
		--房主出资
		if pay_type == PAY_TYPE.ROOM_OWNER_COST then
			local owner_id = room.owner_id
			local owner = room:getPlayerByUserId(owner_id)
			--更新玩家的金币数量
			skynet.send(".mysql_pool","lua","updateGoldNum",-1*cost,owner_id)
			--如果owner不存在 有可能不在游戏中(比如:有人开房给别人玩,自己不玩)
			if owner then
				owner.gold_num = owner.gold_num -1*cost
				local gold_list = {{user_id = owner_id,user_pos = owner.user_pos,gold_num=gold_num}}
				--通知房间中的所有人,有人的金币发生了变化
				room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
			end
		--平摊
		elseif pay_type == PAY_TYPE.AMORTIZED_COST then
			--每个人的花费
			local per_cost = math.floor(cost / seat_num)
			local gold_list = {}
			for i,obj in ipairs(players) do
				skynet.send(".mysql_pool","lua","updateGoldNum",-1*per_cost,obj.user_id)
				obj.gold_num = obj.gold_num -1*per_cost
				local info = {user_id = obj.user_id,user_pos = obj.user_pos,gold_num = gold_num}
				table.insert(gold_list,info)
			end
			room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end   
	end
end

--游戏结束
function game:gameOver(player,over_type,operate,tempResult)
	print("FYD=======>>>游戏结束")

	if over_type == GAME_OVER_TYPE.NORMAL then
		--通知所有人,有人胡了
		local obj = {type = TYPE.HU}
		local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}
		self.room:broadcastAllPlayers("notice_special_event",data)
	end

	-- 计算庄家的位置
	self:updateZpos(player.zpos)

	local room = self.room
	local players = room.player_list
	local cur_round = room.cur_round
	local round = room.round
	local seat_num = room.seat_num
	local room_id = room.room_id

	--计算金币并通知玩家更新
	self:updatePlayerGold(over_type)

	--计算积分并通知玩家
	self:updatePlayerScore(player,over_type,operate,tempResult)

	--更新当前已经完成的局数
	self.room.over_round = self.room.over_round + 1

	local players = self.room.player_list
	for i,player in ipairs(players) do
		player.is_sit = false
	end

	if room.cur_round == room.round then
		room:distory(constant.DISTORY_TYPE.FINISH_GAME)
	end

    local data = {}
    data.room_id = self.room.room_id
    data.over_round = self.room.over_round
	data.cur_round = self.room.cur_round
    skynet.send(".mysql_pool","lua","insertTable","room_list",data)

	self:clear()
	skynet.send(".replay_cord","lua","saveRecord",room.game_type,room.replay_id)
end


--返回房间,推送当局的游戏信息
function game:back_room(user_id)
	local player = self.room:getPlayerByUserId(user_id)


	local refresh_room_info = self.room:getRoomInfo()
    local rsp_msg = {refresh_room_info = refresh_room_info}
	rsp_msg.card_list = player.card_list
	rsp_msg.operator = self.waite_operators[player.user_pos]
	rsp_msg.zpos = self.zpos

	for user_pos,str in pairs(self.waite_operators) do
		if string.find(str,"WAIT_PLAY_CARD") then
			rsp_msg.cur_play_pos = user_pos
		end
	end

	--每个玩家出的牌
	rsp_msg.put_cards = {}
	for user_pos,v in pairs(self.put_cards) do
		table.insert(rsp_msg.put_cards,{cards = v,user_pos = user_pos})
	end
	local handle_nums = {}
	for _,obj in ipairs(self.room.player_list) do
		local handle_num = 0
		if obj.card_list then
			handle_num= #obj.card_list
		end
		local arg = {user_pos=obj.user_pos,handle_num= handle_num}
		table.insert(handle_nums,arg)
	end
	rsp_msg.handle_nums = handle_nums
	rsp_msg.put_card = self.cur_play_card

	player:send({push_all_room_info = rsp_msg})

	return "success"
end

--结算大赢家
function game:distroy()
	local players = self.room.player_list
	local over_round = self.room.over_round
	local round = self.room.round
	-- 大赢家金币结算
	if over_round >= 1 then
		local pay_type = self.pay_type
		--赢家出资 积分高的掏钱
		if pay_type == PAY_TYPE.WINNER_COST then
			-- 积分从高到低排序
			table.sort(players,function(a,b) 
					return a.score > b.score
				end)

			local max_score = players[1].score
			--大赢家列表
			local winners = {}
			for i,obj in ipairs(players) do
				if obj.score >= max_score then
					table.insert(winners,obj)
				end
			end
			local gold_list = { }
			local per_cost = math.floor(cost/#winners)
			for _,obj in ipairs(winners) do

			    skynet.send(".mysql_pool","lua","updateGoldNum",-1*per_cost,obj.user_id)
				obj.gold_num = obj.gold_num -1*per_cost
				local info = {user_id=obj.user_id,user_pos=obj.user_pos,gold_num=gold_num}
				table.insert(gold_list,info)
			end
			self:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end
	end
end

function game:clear()
	self:distroy()
	--清空数据
	local game_meta = {}
	setmetatable(game,game_meta)
	game.__index = game_meta
	game.__newindex = game_meta
end



return game
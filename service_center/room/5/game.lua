local skynet = require "skynet"
local utils = require "utils"
local constant = require "constant"
local cjson = require "cjson"
local judgecard = require "judgecard"
local ALL_CARDS = constant.ALL_CARDS
local ALL_ZJ_MODE = constant.ALL_ZJ_MODE
local ROUND_COST = constant.ROUND_COST
local PAY_TYPE = constant.PAY_TYPE

local engine = require "card_engine/engine"

local game = {}

local GAME_OVER_TYPE = {
	NORMAL = 1, --正常胡牌
	FLOW = 2,	--流局
	DISTROY_ROOM = 3,   --房间解散推送结算积分
}

function game:start(room,recover)
	print("========game start=========")
	self.room = room

	--底分
	self.base_score = self.room.other_setting[1]
	--听牌
	self.ting_card = self.room.other_setting[2] == 1
	--自摸
	self.zimo = self.room.other_setting[3] == 1
	-- 大胡
	self.da_hu = self.room.other_setting[4] == 1

	-- 是否是暗听
	self.is_anting = self.room.other_setting[5] == 1
	
	if room.cur_round == 1 or recover  then
		engine:init(room.seat_num,room.round)
	end
	-- 清空上局的数据
	engine:clear()


	-- 同步玩家的总积分score=>engine
	local list = self.room:getPlayerInfo("user_pos","score")
	for _,info in ipairs(list) do
		engine:setTotalScore(info.user_pos,info.score)
	end

	engine:buildPool()

	local extra_cards = {}

	--填充牌库
	for i=31,37 do
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
		table.insert(extra_cards,i)
	end

	engine:addExtraCards(extra_cards)

	local qiangGangHu = not self.zimo
	--洗牌
	engine:sort()
	engine:setConfig({isPeng = true,isGang = true,isHu = not self.zimo,
		gangAfterTing = true,qiangGangHu=qiangGangHu,shiShanYao=true,anTing = self.is_anting})

	-- 设置庄家模式
	engine:setBankerMode("YING")
	--摸到剩余14张牌的时候，还没有玩家胡牌，则荒庄。
	engine:setflowBureauNum(0)

	if skynet.getenv("mode") == "debug" then
		local data = require "5/conf"
		engine:setDebugPool(data.pool)
		engine:setCurRoundBanker(data.zpos)
	end

	-- 获取本局的庄家
	local banker_pos = engine:getCurRoundBanker()
	-- 随机骰子
	local random_nums = engine:getRandomNums(2)
	-- 发牌
	local deal_cards = engine:dealCard(13)
	for index=1,engine:getPlaceNum() do
		local player = self.room:getPlayerByPos(index)
		local pos = player.user_pos
		local card_list = engine:getHandleCardList(pos)
		
		local rsp_msg = {zpos = banker_pos}
		rsp_msg.cards = deal_cards[pos]
		rsp_msg.user_pos = pos
		rsp_msg.random_nums = random_nums
		rsp_msg.cur_round = self.room.cur_round

		player:send({deal_card = rsp_msg})
	end

	--等待玩家操作的列表
	self.waite_operators = {}
	self.stack_list = {}
 
	--等待所有玩家发回发牌完毕的命令
	for idx=1,engine:getPlaceNum() do
		self.waite_operators[idx] = { operators = { "DEAL_FINISH" }}
	end
end

function game:check_operator(user_pos,...)
	local temp = {...}
	local filters = {}
	for i,operator in ipairs(temp) do
		filters[operator] = true
	end

	if not self.waite_operators[user_pos] then
		return false
	end

	local operators = self.waite_operators[user_pos].operators
	if not operators then
		return false
	end
	for _,voperator in ipairs(operators) do

		if filters[voperator] then
			return true
		end
	end
	return false
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
game["DEAL_FINISH"] = function(self, player,data)

	local user_pos = player.user_pos
	if not self:check_operator(user_pos,"DEAL_FINISH") then
		return "invaild_operator"
	end
	
	self.waite_operators[user_pos] = nil

	--计算剩余的数量
	local _,opt = next(self.waite_operators)
	if not opt then
		--庄家出牌
		local banker_pos = engine:getCurRoundBanker()
		local zplayer = self.room:getPlayerByPos(banker_pos)
		self:drawCard(zplayer)
	end
	return "success"
end

--向A发一张牌 摸牌
function game:drawCard(player)
	local draw_pos = player.user_pos
	local result = engine:drawCard(draw_pos)
	--检查是否流局
	if "FLOW" == result then
		self:gameOver(player,GAME_OVER_TYPE.FLOW)
		return 
	end

 	local card = result
	--通知有人摸牌
	for _,obj in ipairs(self.room.player_list) do
		local data = {user_id = player.user_id,user_pos = draw_pos}
		if obj.user_id == player.user_id then
			data.card = card
		end
		obj:send({push_draw_card = data})
	end

	--通知玩家出牌了
	self:noticePushPlayCard(player,1)
	self.waite_operators[player.user_pos] = { operators = { "PLAY_CARD"},card = card}
end

--通知玩家出牌 operator = 1 摸牌出牌  operator = 2 碰牌出牌
function game:noticePushPlayCard(splayer,operator)
	local players = self.room.player_list
	for i,player in ipairs(players) do
		local rsp_msg = {user_id=splayer.user_id,user_pos=splayer.user_pos}
		if player.user_id == splayer.user_id then
			rsp_msg.card_list = engine:getHandleCardList(player.user_pos)
			rsp_msg.card_stack = engine:getHandleCardStack(player.user_pos)
		end
		rsp_msg.operator = operator
		player:send({push_play_card=rsp_msg})
	end
end

--出牌
game["PLAY_CARD"] = function(self,player,data)
	local user_pos = player.user_pos
	if not self:check_operator(user_pos,"PLAY_CARD") then 
		return "invaild_operator" 
	end
	if not data.card then 
		return "paramater_error" 
	end

	local stack_list = engine:playCard(user_pos,data.card)
	if not stack_list then
		return "invaild_operator"
	end
	
	self.waite_operators[user_pos] = nil

	local user_id = player.user_id
	local data = {user_id = user_id,card = data.card,user_pos = user_pos}
	--通知所有人 A 已经出牌
	self.room:broadcastAllPlayers("notice_play_card",data)
	
	local _,item = next(stack_list)
	if item and #item.operators >= 1 then
		local check_player = self.room:getPlayerByPos(item.pos)
		local rsp_msg = {push_player_operator_state = {operator_list=item.operators,user_pos=item.pos,card=item.card}}
		check_player:send(rsp_msg)
		table.insert(item.operators,"GUO")
		self.waite_operators[item.pos] = { operators = item.operators ,card = item.card}
		table.remove(stack_list,1)
		self.stack_list = stack_list
	else
		local next_pos = engine:getNextPutPos()
		local next_player = self.room:getPlayerByPos(next_pos)
		self:drawCard(next_player)
	end

	return "success"
end

-- 听牌
game["TING_CARD"] = function(self,player,data)
	local user_pos = player.user_pos
	if not self.ting_card then
		return "invaild_operator" 
	end

	if not self:check_operator(user_pos,"PLAY_CARD") then 
		return "invaild_operator" 
	end 
	if not data.card then 
		return "paramater_error" 
	end
 
	-- 如果当前已经是听牌状态了
	if engine:getTing(user_pos) then
		return "invaild_operator"
	end

	local result,stack_list, obj = engine:tingCard(user_pos,data.card)
	if not result then
		return "invaild_operator"
	end
	-- 回放的时候需要删除牌, 把真实牌值传给前段使用
	local dataMsg = {user_id = player.user_id, user_pos = player.user_pos}

	dataMsg.item = {}
	for i, v in pairs(obj) do 
		dataMsg.item[i] = v
	end

	dataMsg.item.value = data.card
	self.room:broadcastAllPlayers("notice_special_event", dataMsg)

	-- 给前段发送出牌消息
	local data = {user_id = player.user_id, card = obj.value, user_pos = player.user_pos}
	--通知所有人 A 已经出牌
	self.room:broadcastAllPlayers("notice_play_card",data)


	if not stack_list then
		stack_list = {}
	end
	local _,item = next(stack_list)
	if item and #item.operators >= 1 then
		local check_player = self.room:getPlayerByPos(item.pos)
		local rsp_msg = {push_player_operator_state = {operator_list=item.operators,user_pos=item.pos,card=item.card}}
		check_player:send(rsp_msg)
		table.insert(item.operators,"GUO")
		self.waite_operators[item.pos] = { operators = item.operators ,card = item.card}
		table.remove(stack_list,1)
		self.stack_list = stack_list
	else
		local next_pos = engine:getNextPutPos()
		local next_player = self.room:getPlayerByPos(next_pos)
		self:drawCard(next_player)
	end

	return "success"
end

--碰
game["PENG"] = function(self,player,data)
 
	if not self:check_operator(player.user_pos,"PENG") then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil

	local obj = engine:pengCard(player.user_pos)
	if not obj then
		return "invaild_operator"
	end
 
	--通知所有人,有人碰了
	local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}

	self.room:broadcastAllPlayers("notice_special_event",data)

	--通知玩家出牌
	local operator = 2
	self:noticePushPlayCard(player,operator)

	self.waite_operators[player.user_pos] = { operators = { "PLAY_CARD"} }

	return "success"
end

--杠
game["GANG"] = function(self,player,data,isGuo)
	local card = data.card 

	if not self:check_operator(player.user_pos,"GANG") and not self:check_operator(player.user_pos,"PLAY_CARD") then
		return "invaild_operator"
	end
	if isGuo then
		engine:updateConfig({qiangGangHu=false})
	end
	local obj,stack_list = engine:gangCard(player.user_pos,card)
	if not obj then
		return "invaild_operator"
	end
	if isGuo then
		engine:updateConfig({qiangGangHu=true})
	end
	self.waite_operators[player.user_pos] = nil
	
	

	if obj ~= "QIANG_GANG" then
		--如果点杠的人已经报听,则该杠三家扣分
		if engine:getTing(obj.from) then
			local conf = {mode = "ALL",score = self.base_score}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		else
			-- 杠的分数计算
			if obj.type == engine:getConstant("TYPE","MING_GANG") then
				local conf = {mode = "ONE" ,score = 1*self.base_score}
				engine:updateScoreFromConf(obj,conf,player.user_pos)
			elseif obj.type == engine:getConstant("TYPE","PENG_GANG") then
				local conf = {mode = "ONE" ,score = 1*self.base_score}
				engine:updateScoreFromConf(obj,conf,player.user_pos)
			elseif obj.type == engine:getConstant("TYPE","AN_GANG") then
				local conf = {mode = "ALL",score = self.base_score}
				engine:updateScoreFromConf(obj,conf,player.user_pos)
			end
		end


		

		--通知所有人,有人杠了
		local data = {user_id = player.user_id,user_pos = player.user_pos,item = obj}
		self.room:broadcastAllPlayers("notice_special_event",data)
		
		for _,obj in ipairs(self.room.player_list) do
			obj.cur_score = engine:getCurScore(obj.user_pos)
			obj.score = engine:getTotalScore(obj.user_pos)
			obj.card_list = engine:getHandleCardList(obj.user_pos)
			self.room:updatePlayerProperty(obj.user_id,"score",obj.score)
			self.room:updatePlayerProperty(obj.user_id,"cur_score",obj.cur_score)
		end

		local list = engine:getRecentDeltScore()
		local data = self.room:getPlayerInfo("user_id","user_pos","score")
		for idx,info in ipairs(data) do
			data[idx].delt_score = list[info.user_pos]
		end

		self.room:broadcastAllPlayers("refresh_player_cur_score",{cur_score_list=data})
	end
	
	local list = engine:getRecentDeltScore()
	local data = self.room:getPlayerInfo("user_id","user_pos")
	for idx,info in ipairs(data) do
		data[idx].delt_score = list[info.user_pos]
	end

	self.room:broadcastAllPlayers("refresh_player_cur_score",{cur_score_list=data})
	if not stack_list then
		stack_list = {}
	end
	local _,item = next(stack_list)
	if item and #item.operators >= 1 then
		local check_player = self.room:getPlayerByPos(item.pos)
		local rsp_msg = {push_player_operator_state = {operator_list=item.operators,user_pos=item.pos,card=item.card}}
		check_player:send(rsp_msg)
		table.insert(item.operators,"GUO")
		self.waite_operators[item.pos] = { operators = item.operators ,card = item.card}
		table.remove(stack_list,1)
		self.stack_list = stack_list
	else
		--杠了之后再摸一张牌
		self:drawCard(player)
	end
 
	return "success"
end

--过
game["GUO"] = function(self,player,data)

	if not self:check_operator(player.user_pos,"GUO") then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil
	--检测是否该下一个人操作
	local _,item = next(self.stack_list)
	if item and #item.operators > 0 then
		if item.operators[1] ~= "GANG" then
			local check_player = self.room:getPlayerByPos(item.pos)
			local rsp_msg = {push_player_operator_state = {operator_list=item.operators,user_pos=item.pos,card=item.card}}
			check_player:send(rsp_msg)
			table.insert(item.operators,"GUO")
			self.waite_operators[item.pos] = { operators = item.operators }
		else
			local obj = self.room:getPlayerByPos(item.pos)
			self.waite_operators[item.pos] = { operators = item.operators }
			game["GANG"](game,obj,{card = item.card},true)
		end
		table.remove(self.stack_list,1)
		return "success"
	end
	-- 下一个人出牌
	local next_pos = engine:getNextPutPos()
	local next_player = self.room:getPlayerByPos(next_pos)
	self:drawCard(next_player)

	return "success"
end

--胡牌
game["HU"] = function(self,player,data)

	if (not self:check_operator(player.user_pos,"HU")) and (not self:check_operator(player.user_pos,"PLAY_CARD")) then
		return "invaild_operator"
	end
	local operate = self.waite_operators[player.user_pos]
	self.waite_operators[player.user_pos] = nil
	local card = operate.card

	local obj,refResult = engine:huCard(player.user_pos,card)
	if not obj then
		return "invaild_operator"
	end
	

	--通知所有人,有人胡了
	local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}
	self.room:broadcastAllPlayers("notice_special_event",data)

	--算番
	local max = 1
 	-- 大胡需要算番
 	if self.da_hu then
		for key,value in pairs(refResult.fans) do
			if key == "QING_YI_SE" or key == "QI_XIAO_DUI" or key == "YI_TIAO_LONG"  then
				if max < 2 then
					max = 2
				end
			elseif key == "HAO_HUA_QI_XIAO_DUI" then
				if max < 18 then
					max = 18
				end
			elseif key == "SHI_SHAN_YAO" then
				if max < 27 then
					max = 27
				end
			end
		end
 	end

 	--自摸(赢三家)
	if refResult.isZiMo then
		local conf = {mode = "ALL" ,score = 2 * self.base_score* max}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	else
		--不报听点炮(包赔)  报听点炮(三家赔)  
		local ting = engine:getTing(obj.from)
		if not ting then
			local conf = {mode = "ONE" ,score = 3*self.base_score*max}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		else
			local conf = {mode = "ALL" ,score = self.base_score*max}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		end
	end

	local info = self.room:getPlayerInfo("user_id","user_pos")
	for _,obj in ipairs(info) do
		obj.cur_score = engine:getCurScore(obj.user_pos)
		obj.score = engine:getTotalScore(obj.user_pos)
		obj.card_list = engine:getHandleCardList(obj.user_pos)
		self.room:updatePlayerProperty(obj.user_id,"score",obj.score)
		self.room:updatePlayerProperty(obj.user_id,"cur_score",obj.cur_score)
	end

	local data = {over_type = GAME_OVER_TYPE.NORMAL,players = info}

	data.winner_pos = player.user_pos
	if refResult.isZiMo then
		data.winner_type = constant["WINNER_TYPE"].ZIMO
	else
		data.winner_type = constant["WINNER_TYPE"].DIAN_PAO
	end
	local players = room.player_list
	-- 更新下明杠暗杠以及胡牌的计数
	for _,obj in ipairs(players) do
		obj.an_gang_num = engine:getTotalAnGangNum(obj.user_pos)
		obj.ming_gang_num = engine:getTotalMingGangNum(obj.user_pos)
		obj.hu_num = engine:getTotalHuNum(obj.user_pos)
	end
	
	--回合结束
	room:roundOver()

	data.last_round = self.room.over_round >= self.room.round

	self.room:broadcastAllPlayers("notice_game_over",data)

	self:gameOver(player,GAME_OVER_TYPE.NORMAL,refResult)

	return "success"
end
 

--更新玩家的金币
function game:updatePlayerGold(over_type)
	if over_type == GAME_OVER_TYPE.DISTROY_ROOM then
		return 
	end
	local room = self.room
	local players = room.player_list
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
				local gold_list = {{user_id = owner_id,user_pos = owner.user_pos,gold_num=owner.gold_num}}
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
				local info = {user_id = obj.user_id,user_pos = obj.user_pos,gold_num = obj.gold_num}
				table.insert(gold_list,info)
			end
			room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end   
	end
end

--游戏结束
function game:gameOver(player,over_type,tempResult)
	print("FYD=======>>>游戏结束")

	local room = self.room
	local players = self.room.player_list
 
	if over_type == GAME_OVER_TYPE.FLOW then
		--流局 商丘麻将需要重置积分
		engine:resetOriginScore()
		for _,obj in ipairs(self.room.player_list) do
			obj.cur_score = engine:getCurScore(obj.user_pos)
			obj.score = engine:getTotalScore(obj.user_pos)
			obj.card_list = engine:getHandleCardList(obj.user_pos)
			self.room:updatePlayerProperty(obj.user_id,"score",obj.score)
			self.room:updatePlayerProperty(obj.user_id,"cur_score",obj.cur_score)
		end
		local info = self.room:getPlayerInfo("user_id","user_pos","cur_score","score","card_list")
		local data = {over_type = GAME_OVER_TYPE.FLOW,players = info}
		data.last_round = self.room.over_round >= self.room.round
		self.room:broadcastAllPlayers("notice_game_over",data)
	end
	--计算金币并通知玩家更新
	self:updatePlayerGold(over_type)

	if self.room.over_round >= self.room.round then
		self.room:distroy(constant.DISTORY_TYPE.FINISH_GAME)
	end
end


--返回房间,推送当局的游戏信息
function game:back_room(user_id)
	local player = self.room:getPlayerByUserId(user_id)

	local refresh_room_info = self.room:getRoomInfo()
    local rsp_msg = {refresh_room_info = refresh_room_info}
	rsp_msg.card_list = engine:getHandleCardList(player.user_pos)

	local card_stack = self.room:getPlayerInfo("user_pos")
	for i,obj in ipairs(card_stack) do
		obj.item = engine:getHandleCardStack(obj.user_pos)
	end
	rsp_msg.card_stack = card_stack

	if self.waite_operators[player.user_pos] then
		rsp_msg.operators = self.waite_operators[player.user_pos].operators
		rsp_msg.card = self.waite_operators[player.user_pos].card
	end
	
	rsp_msg.zpos = engine:getCurRoundBanker()
	rsp_msg.put_pos = engine:getLastPutPos()
	rsp_msg.reduce_num = #engine:getCardPool()
	for user_pos,obj in pairs(self.waite_operators) do
		if self:check_operator(user_pos,"PLAY_CARD") then
			rsp_msg.cur_play_pos = user_pos
			rsp_msg.cur_play_operators = obj.operators
		end
	end
	rsp_msg.ting_card = engine:getTing(player.user_pos)

	local ting_list = {}
	for pos=1,engine:getPlaceNum() do
		local ting = engine:getTing(pos) and true or false
		local temp = {user_pos=pos,ting = ting}
		table.insert(ting_list,temp)
	end
	
	rsp_msg.ting_list = ting_list

	--每个玩家出的牌
	rsp_msg.put_cards = {}
	rsp_msg.handle_nums = {}
	rsp_msg.four_card_list = self.four_card_list

	for pos=1,engine:getPlaceNum() do
		local cards = engine:getPutCard(pos)
		table.insert(rsp_msg.put_cards,{cards = cards,user_pos = pos})

		local handle_num = #engine:getHandleCardList(pos)
		local arg = {user_pos=pos,handle_num= handle_num}
		table.insert(rsp_msg.handle_nums,arg)
	end
	--markList
	local mark_list = {}
	for pos=1,engine:getPlaceNum() do
		local cards = engine:getMarkList(pos)
		local temp = {user_pos=pos,cards = cards}
		table.insert(mark_list,temp)
	end

	rsp_msg.mark_list = mark_list

	rsp_msg.put_card = engine:getLastPutCard()
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
				local info = {user_id=obj.user_id,user_pos=obj.user_pos,gold_num=obj.gold_num}
				table.insert(gold_list,info)
			end
			self:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end
	end
end
return game
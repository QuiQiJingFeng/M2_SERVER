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

function game:start(room)
	print("========game start=========")
	self.room = room
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

	if room.cur_round == 1 then
		engine:init(room.seat_num,room.round)
	end
	-- 清空上局的数据
	engine:clear()

	-- 同步room的 over_round/cur_round=>到engine
	engine:setCurRound(room.cur_round)
	engine:setOverRound(room.over_round)

	-- 同步玩家的总积分score=>engine
	local list = self.room:getPlayerInfo("user_pos","score")
	for _,info in ipairs(list) do
		engine:setTotalScore(info.user_pos,info.score)
	end
	-- 编辑牌库
	engine:buildPool()
	local extra_cards = {35,35,35,35}
	engine:addExtraCards(extra_cards)

	--洗牌
	engine:sort()

	engine:settingConfig({isHu=false,isQiDui=self.seven_pairs,huiCard=35,hiPoint=true})

	-- 设置庄家模式
	engine:setBankerMode("YING")
	-- 设置流局的张数
	engine:setflowBureauNum(self.award_num)

	-- 获取本局的庄家
	local banker_pos = engine:getCurRoundBanker()
	-- 随机骰子
	local random_nums = engine:getRandomNums(2)
	 
	-- 发牌
	local deal_cards = engine:dealCard(13)
	for index=1,engine:getPlaceNum() do
		local player = self.room:getPlayerByPos(index)
		local pos = player.user_pos
		local card_list = engine:getPlaceCards(pos)
		
		local rsp_msg = {zpos = banker_pos}
		rsp_msg.cards = deal_cards[pos]
		rsp_msg.user_pos = pos
		rsp_msg.random_nums = random_nums
		rsp_msg.cur_round = engine:getCurRound()
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
game["DEAL_FINISH"] = function(self, player)

	local user_pos = player.user_pos
	if not self:check_operator(user_pos,"DEAL_FINISH") then
		return "invaild_operator"
	end
	self.waite_operators[user_pos] = nil
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
	self.waite_operators[draw_pos] = { operators = { "PLAY_CARD","GANG","HU"},card = card}
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
	if not data.card or data.card == 35 then 
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
game["GANG"] = function(self,player,data)
	local card = data.card 
	if not self:check_operator(player.user_pos,"GANG") then
		return "invaild_operator"
	end
	local obj,stack_list = engine:gangCard(player.user_pos,card)
	if not obj then
		return "invaild_operator"
	end
 
	self.waite_operators[player.user_pos] = nil

	-- 杠的分数计算
	if obj.type == engine:getConstant("TYPE","MING_GANG") then
		local conf = {mode = "ONE" ,score = self.base_score * 3}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	elseif obj.type == engine:getConstant("TYPE","PENG_GANG") then
		local conf = {mode = "ALL" ,score = self.base_score * 1}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	elseif obj.type == engine:getConstant("TYPE","AN_GANG") then
		local conf = {mode = "ALL",score = self.base_score * 2}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end
  
	--通知所有人,有人杠了
	local data = {user_id = player.user_id,user_pos = player.user_pos,item = obj}
	self.room:broadcastAllPlayers("notice_special_event",data)
	
	local list = engine:getRecentDeltScore()
	local data = self.room:getPlayerInfo("user_id","user_pos")
	for idx,info in ipairs(data) do
		data[idx].delt_score = list[info.user_pos]
	end

	self.room:broadcastAllPlayers("refresh_player_cur_score",{cur_score_list=data})
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
	if item then
		local check_player = self.room:getPlayerByPos(item.pos)
		local rsp_msg = {push_player_operator_state = {operator_list=item.operators,user_pos=item.pos,card=item.card}}
		check_player:send(rsp_msg)
		table.insert(item.operators,"GUO")
		self.waite_operators[item.pos] = { operators = item.operators }
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

	if not self:check_operator(player.user_pos,"HU") then
		return "invaild_operator"
	end
	local operate = self.waite_operators[player.user_pos]
	self.waite_operators[player.user_pos] = nil
 	local card = operate.card
	local obj,refResult = engine:huCard(player.user_pos,card)

	if not obj then
		return "invaild_operator"
	end
	-- 自摸赢每个玩家2*底分
	if refResult.isZiMo then
		local conf = {mode = "ALL" ,score = self.base_score * 2}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end

	if self.hi_point and refResult.huiNum == 4 then 
		--摸到四张红中胡牌，赢每个玩家2*底分
		local conf = {mode = "ALL" ,score = self.base_score * 2}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end
	
	if self.seven_pairs and refResult.isQiDui then
		--胡七对 赢每个玩家2*底分
		local conf = {mode = "ALL" ,score = self.base_score * 2}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end

	local award_num = self.award_num
	--每一张码 赢每个玩家2*底分
	if refResult.iHuiNum == 0 then
		--如果没有红中,则额外奖励两张码
		award_num = award_num + 2
	end

	local award_list = engine:getPoolLastCards(award_num)
	-- 中码数量
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
	-- 每个码赢每个玩家2*底分
	if num > 0 then
		local conf = {mode = "ALL" ,score = self.base_score * 2 * num}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end

	local info = self.room:getPlayerInfo("user_id","user_pos")
	for _,obj in ipairs(info) do
		obj.cur_score = engine:getCurScore(obj.user_pos)
		obj.score = engine:getTotalScore(obj.user_pos)
		obj.card_list = engine:getHandleCardList(obj.user_pos)
	end
	player.reward_num = player.reward_num + #award_list
	local data = {over_type = GAME_OVER_TYPE.NORMAL,players = info,award_list=award_list}

	data.winner_pos = player.user_pos
	if refResult.isZiMo then
		data.winner_type = constant["WINNER_TYPE"].ZIMO
	else
		data.winner_type = constant["WINNER_TYPE"].DIAN_PAO
	end

	data.last_round = engine:isGameEnd()

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
				print("cjson--->>",cjson.encode(gold_list))
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
function game:gameOver(player,over_type,operate,refResult)
	print("FYD=======>>>游戏结束")

	local room = self.room
	local players = self.room.player_list
	for i,player in ipairs(players) do
		player.is_sit = false
	end
 	--计算金币并通知玩家更新
	self:updatePlayerGold(over_type)

	--更新当前已经完成的局数
	self.room.over_round = engine:getOverRound()
	-- 更新下明杠暗杠以及胡牌的计数
	for _,obj in ipairs(players) do
		obj.an_gang_num = engine:getTotalAnGangNum(obj.user_pos)
		obj.ming_gang_num = engine:getTotalMingGangNum(obj.user_pos)
		obj.hu_num = engine:getTotalHuNum(obj.user_pos)
	end

 	if engine:isGameEnd() then
		room:distroy(constant.DISTORY_TYPE.FINISH_GAME)
	end

    local data = {}
    data.room_id = self.room.room_id
    data.over_round = engine:getOverRound()
	data.cur_round = engine:getCurRound()
    skynet.send(".mysql_pool","lua","insertTable","room_list",data)

    -- 同步玩家的个人数据到数据库
    self.room:updatePlayersToDb()
	skynet.send(".replay_cord","lua","saveRecord",room.game_type,room.replay_id)
end


--返回房间,推送当局的游戏信息
function game:back_room(user_id)
	local player = self.room:getPlayerByUserId(user_id)

	local refresh_room_info = self.room:getRoomInfo()
    local rsp_msg = {refresh_room_info = refresh_room_info}

	rsp_msg.card_list = player.card_list
	rsp_msg.operators = self.waite_operators[player.user_pos].operators
	rsp_msg.zpos = engine:getCurRoundBanker()
	rsp_msg.put_pos = engine:getLastPutPos()
	rsp_msg.reduce_num = #engine:getCardPool()
	for user_pos,obj in pairs(self.waite_operators) do
		if self:check_operator(user_pos,"PLAY_CARD") then
			rsp_msg.cur_play_pos = user_pos
			rsp_msg.cur_play_operators = obj.operators
		end
	end

	--每个玩家出的牌
	rsp_msg.put_cards = {}
	rsp_msg.handle_nums = {}
	for pos=1,engine:getPlaceNum() do
		local cards = engine:getPutCard(pos)
		table.insert(rsp_msg.put_cards,{cards = cards,user_pos = pos})

		local handle_num = #engine:getHandleCardList(pos)
		local arg = {user_pos=pos,handle_num= handle_num}
		table.insert(rsp_msg.handle_nums,arg)
	end
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
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
	--带风
	self.dai_feng = self.room.other_setting[2] == 1
	--下跑
	self.xia_pao = self.room.other_setting[3] == 1
	--暗杠锁死
	self.an_gang_suo_si = self.room.other_setting[4] == 1
	--亮四打一
	self.liang_si_da_yi = self.room.other_setting[5] == 1
	--掐张
	self.qia_zhang = self.room.other_setting[6] == 1
	--偏次
	self.pian_ci = self.room.other_setting[7] == 1
	--缺门
	self.que_men = self.room.other_setting[8] == 1
	--门清
	self.men_qing = self.room.other_setting[9] == 1
	--暗卡
	self.an_ka = self.room.other_setting[10] == 1
	--自摸加嘴
	self.jia_zui = self.room.other_setting[11] == 1
	--对对胡
	self.dui_dui_hu = self.room.other_setting[12] == 1

	if room.cur_round == 1 then
		engine:init(room.seat_num)
	end
	-- 清空上局的数据
	engine:clear()

	-- 同步room的 over_round/cur_round=>到engine
	engine:setOverRound(room.over_round)
	engine:setCurRound(room.cur_round)

	-- 同步玩家的总胡数、暗杠、明杠数量
	for _,obj in ipairs(room.player_list) do
		engine:setTotalHuNum(obj.user_pos,obj.hu_num or 0)
		engine:setTotalAnGangNum(obj.user_pos,obj.an_gang_num or 0)
		engine:setTotalMingGangNum(obj.user_pos,obj.ming_gang_num or 0)
	end

	-- 同步玩家的总积分score=>engine
	local list = self.room:getPlayerInfo("user_pos","score")
	for _,info in ipairs(list) do
		engine:setTotalScore(info.user_pos,info.score)
	end

	engine:buildPool()

	local extra_cards = {}
	-- for i=41,48 do
	-- 	table.insert(extra_cards,i)
	-- end

	--带风
	if self.dai_feng then
		--填充牌库
 		for i=31,37 do
 			table.insert(extra_cards,i)
 			table.insert(extra_cards,i)
 			table.insert(extra_cards,i)
 			table.insert(extra_cards,i)
 		end
	end
	engine:addExtraCards(extra_cards)

	--洗牌
	engine:sort()

	-- 设置庄家模式
	engine:setBankerMode("YING")

	engine:setflowBureauNum(0)

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
		-- 亮四打1
		if self.liang_si_da_yi then
			local four_card_list = {}
			for idx=1,engine:getPlaceNum() do
				local obj = {user_pos = idx,cards = {}}
				-- 亮4张牌
				for i=1,4 do
					local card = deal_cards[idx][i]
					table.insert(obj.cards,card)
				end
				table.insert(four_card_list,obj)
			end
			rsp_msg.four_card_list = four_card_list
			self.four_card_list = four_card_list
		end



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

	-- 下跑
	local pao_num = data.pao_num or 0
	engine:setRecordData(user_pos,"pao_num",pao_num)
	
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
		--TODO
		self:gameOver(player,GAME_OVER_TYPE.FLOW)
		return 
	end

 	local card = result
	--通知有人摸牌
	for _,obj in ipairs(self.room.player_list) do
		local data = {user_id = user_id,user_pos = draw_pos}
		if obj.user_id == user_id then
			data.card = card
		end
		obj:send({push_draw_card = data})
	end

	--通知玩家出牌了
	self:noticePushPlayCard(player,1)
	self.waite_operators[player.user_pos] = { operators = { "PLAY_CARD","GANG","HU"},card = card}
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
	-- 亮四打一 不能出那四张牌
	if self.liang_si_da_yi then
		for _,item in ipairs(self.four_card_list) do
			-- 检查亮的四张牌中有几张 这个牌
			local card_num = 0
			for _,value in ipairs(item.cards) do
				if value == data.card then
					card_num = card_num + 1
				end
			end

			if card_num > 0 then
				local num = engine:getCardNum(item.user_pos,card)
				if num <= card_num then
					return "invaild_operator"
				end
			end
		end
		
	end

	self.waite_operators[user_pos] = nil

	--花牌  补花 
	if data.card > 40 then
		engine:addExtraScore(user_pos,1)
	end

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
		local conf = {mode = "ONE" ,score = 1}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	elseif obj.type == engine:getConstant("TYPE","PENG_GANG") then
		local conf = {mode = "ONE" ,score = 1}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	elseif obj.type == engine:getConstant("TYPE","AN_GANG") then
		local conf = {mode = "ALL",score = 2}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	end

	-- 暗杠锁死 ,锁死之后不能再点炮和抢杠胡
	if self.an_gang_suo_si then
		engine:settingConfig({isHu = false,qiangGangHu = false})
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

	if obj then
		--通知所有人,有人胡了
		local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}
		self.room:broadcastAllPlayers("notice_special_event",data)

		local hufen = self.base_score

		local zui_score = 1  --报听的一分
		if self.men_qing and refResult.fans["MEN_QING"] then
			zui_score = zui_score + 1
		end

		if self.an_ka then
			local anka_num = refResult.fans["AN_KA"] 
			if anka_num and anka_num > 0 then
				zui_score = zui_score + anka_num
			end
		end

		if self.qia_zhang and refResult.fans["QIA_ZHANG"] then
			zui_score = zui_score + 1
		end

		if self.pian_ci and refResult.fans["BIAN_ZHANG"] then
			zui_score = zui_score + 1
		end

		if self.que_men then
			local quemen_num = refResult.fans["AN_KA"]
			if quemen_num > 0 then
				zui_score = zui_score + quemen_num
			end
		end
		-- 自摸+1嘴
		if self.jia_zui and refResult.isZiMo then
			zui_score = zui_score + 1
		end

		hufen = hufen + zui_score

		if self.dui_dui_hu and refResult.isQiDui then
			hufen = hufen + 1
		end

		local extra_score = engine:getExtraScore(player.user_pos)
		local total_score = hufen + extra_score

		if refResult.isZiMo then
			local conf = {mode = "ALL" ,score = total_score,add = "pao_num"}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		else
			local conf = {mode = "ONE" ,score = total_score,add = "pao_num"}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		end

		local info = self.room:getPlayerInfo("user_id","user_pos")
		for _,obj in ipairs(info) do
			obj.cur_score = engine:getCurScore(obj.user_pos)
			obj.score = engine:getTotalScore(obj.user_pos)
			obj.card_list = engine:getHandleCardList(obj.user_pos)
		end

		local data = {over_type = over_type,players = info}

		data.winner_pos = player.user_pos
		if refResult.isZiMo then
			data.winner_type = constant["WINNER_TYPE"].ZIMO
		else
			data.winner_type = constant["WINNER_TYPE"].DIAN_PAO
		end
 
		data.last_round = engine:isGameEnd()

		self.room:broadcastAllPlayers("notice_game_over",data)

		self:gameOver(player,GAME_OVER_TYPE.NORMAL,refResult)
	end

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
function game:gameOver(player,over_type,tempResult)
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
		obj.an_gang_num = engine:getTotalAnGangNum()
		obj.ming_gang_num = engine:getTotalMingGangNum()
		obj.hu_num = engine:getTotalHuNum()
	end

 	if engine:isGameEnd() then
		room:distory(constant.DISTORY_TYPE.FINISH_GAME)
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

return game
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
	-- 是否是暗听
	self.is_anting = self.room.other_setting[13] == 1

	if room.cur_round == 1 or recover then
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
	for i=41,48 do
		table.insert(extra_cards,i)
	end

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
	engine:setDefaultConfig()
	engine:updateConfig({anTing=self.is_anting})

	-- 设置庄家模式
	engine:setBankerMode("YING")
	--摸到剩余14张牌的时候，还没有玩家胡牌，则荒庄。
	engine:setflowBureauNum(14)

	if skynet.getenv("mode") == "debug" then
		local data = require "3/conf"
		engine:setDebugPool(data.pool)
		engine:setCurRoundBanker(data.zpos)
	end

	--等待玩家操作的列表
	self.waite_operators = {}
	self.stack_list = {}
	self.all_pao = nil
	-- 第n次开杠、补花
	self.gang_hua = 0

	if self.xia_pao then
		for idx=1,engine:getPlaceNum() do
			self.waite_operators[idx] = { operators = { "PAO" }}
		end

		self.room:broadcastAllPlayers("notice_pao",{})
	else
		self:dealCard()
	end
end

function game:dealCard()
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

	--等待所有玩家发回发牌完毕的命令
	for idx=1,engine:getPlaceNum() do
		self.waite_operators[idx] = { operators = { "DEAL_FINISH" }}
	end
end

--下跑
game["PAO"] = function(self,player,data)
	local user_pos = player.user_pos
	if not self:check_operator(user_pos,"PAO") then
		return "invaild_operator"
	end


	self.waite_operators[user_pos] = {}
	-- 下跑
	local pao_num = data.pao_num == 1
	engine:setRecordData(user_pos,"pao_num",pao_num and 1 or 0)
	if not self.all_pao then
		self.all_pao = 1
	else
		self.all_pao = self.all_pao + 1
	end

	if self.all_pao < engine:getPlaceNum() then
		return "success"
	end

	self:dealCard()
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
function game:drawCard(player,special,last,in_liangsidayi)
	local draw_pos = player.user_pos
	local result = engine:drawCard(draw_pos,special,last)
	--检查是否流局
	if "FLOW" == result then
		self:gameOver(player,GAME_OVER_TYPE.FLOW)
		return 
	end

 	local card = result

	if in_liangsidayi then
		for _,item in ipairs(self.four_card_list) do
			if item.user_pos == draw_pos then
				-- 检查亮的四张牌中有几张 这个牌
				if #item.cards >= 4 then
					print("ERROR=>参数错误")
				else
					table.insert(item.cards,card)
				end
				break
			end
		end
	end

	--通知有人摸牌
	for _,obj in ipairs(self.room.player_list) do
		local data = {user_id = player.user_id,user_pos = draw_pos,in_liangsidayi = in_liangsidayi}
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
		rsp_msg.four_card_list = self.four_card_list
		rsp_msg.operator = operator
		player:send({push_play_card=rsp_msg})
	end
end

function game:checkLiangSiDaYi(pos,card)
	if self.liang_si_da_yi then
		for _,item in ipairs(self.four_card_list) do
			if item.user_pos == pos then
				-- 检查亮的四张牌中有几张 这个牌
				local card_num = 0
				for _,value in ipairs(item.cards) do
					if value == card then
						card_num = card_num + 1
					end
				end
				return card_num > 0 and card_num or false
			end
		end
	end
	return false
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

	local all_num = engine:getCardNum(user_pos,data.card)
	local card_in_liangsidayi = false
	-- 亮四打一 不能出那四张牌
	local in_num = self:checkLiangSiDaYi(user_pos,data.card)
	if in_num then
			local can_play = false
			for _,item in ipairs(self.four_card_list) do
				if item.user_pos == user_pos then
					if #item.cards >= 4 or data.card > 40 then
						for i,card in ipairs(item.cards) do
							if card == data.card then
								table.remove(item.cards,i)
								break;
							end
						end

						can_play = true
						break;
					end 
				end
 			end
 			card_in_liangsidayi = can_play
			if not can_play then
				--如果该亮四打一的牌不能出,那么检查手牌是否能出,如果能,则出手牌
				if not(all_num > in_num) then
					return "in_four_cardlist"
				end
			end
	end

	local stack_list = engine:playCard(user_pos,data.card,nil,data.card > 40)
	if not stack_list then
		return "operator_error"
	end
	

	self.waite_operators[user_pos] = nil

	local user_id = player.user_id
	local data = {user_id = user_id,card = data.card,user_pos = user_pos}
	--通知所有人 A 已经出牌
	self.room:broadcastAllPlayers("notice_play_card",data)

	--花牌  补花 
	if data.card > 40 then
		self.gang_hua = self.gang_hua + 1
		--当第基数次开杠或者补花时候，且荒庄数再往前移两张
		if self.gang_hua %2 == 1 then
			engine:setflowBureauNum(15)
		else
			engine:setflowBureauNum(14)
		end
		engine:updateRecordData(user_pos,"hua",1)
		self:drawCard(player,nil,true,card_in_liangsidayi)
		return "success"
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

-- 听牌
game["TING_CARD"] = function(self,player,data)
	local user_pos = player.user_pos
	if not self:check_operator(user_pos,"PLAY_CARD") then 
		return "invaild_operator" 
	end
	if not data.card then 
		return "paramater_error" 
	end
 
	local all_num = engine:getCardNum(user_pos,data.card)
	local card_in_liangsidayi = false
	-- 亮四打一 不能出那四张牌
	local in_num = self:checkLiangSiDaYi(user_pos,data.card)
	if in_num then
			local can_play = false
			for _,item in ipairs(self.four_card_list) do
				if item.user_pos == user_pos then
					if #item.cards >= 4 or data.card > 40 then
						for i,card in ipairs(item.cards) do
							if card == data.card then
								table.remove(item.cards,i)
								break;
							end
						end

						can_play = true
						break;
					end 
				end
 			end
 			card_in_liangsidayi = can_play
			if not can_play then
				--如果该亮四打一的牌不能出,那么检查手牌是否能出,如果能,则出手牌
				if not(all_num > in_num) then
					return "in_four_cardlist"
				end
			end
	end
	


	-- 如果当前已经是听牌状态了
	if engine:getTing(user_pos) then
		return "already_ting_card"
	end

	local result,stack_list,obj = engine:tingCard(user_pos,data.card)
	if not result then
		return "operator_error"
	end
	self.waite_operators[user_pos] = nil
	local origin_value = obj.value
	obj.value = data.card
	local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}
	self.room:broadcastAllPlayers("notice_special_event",data)

	-- 给前段发送出牌消息
	local data = {user_id = player.user_id, card = origin_value, user_pos = player.user_pos}
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
		return "operator_error"
	end
	-- 检测该牌是否属于亮四打一
	local liangsi = self:checkLiangSiDaYi(player.user_pos,obj.value)
	if liangsi then
		-- 如果某张牌属于亮四打一的牌,则将其从亮四打一的牌中去掉
		for _,item in ipairs(self.four_card_list) do
			if item.user_pos == player.user_pos then
				local rm_num = 2
				for i=#item.cards,1,-1 do
					local card = item.cards[i]
					if card == obj.value and rm_num > 0 then
						table.remove(item.cards,i)
						rm_num = rm_num - 1
					end
				end
			end
		end
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
		return "operator_error"
	end
	if isGuo then
		engine:updateConfig({qiangGangHu=true})
	end
	self.waite_operators[player.user_pos] = nil
	-- 检测该牌是否属于亮四打一
	local liangsi = self:checkLiangSiDaYi(player.user_pos,obj.value)
	if liangsi and obj ~= "QIANG_GANG" then
		-- 将亮四打一中所有该牌值的牌删掉
		for _,item in ipairs(self.four_card_list) do
			if item.user_pos == player.user_pos then
				for i=#item.cards,1,-1 do
					local card = item.cards[i]
					if card == obj.value then
						table.remove(item.cards,i)
					end
				end
			end
		end
	end
	
	if obj ~= "QIANG_GANG" then
		-- 杠的分数计算
		if obj.type == engine:getConstant("TYPE","MING_GANG") then
			local conf = {mode = "ONE" ,score = 1*self.base_score}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		elseif obj.type == engine:getConstant("TYPE","PENG_GANG") then
			local conf = {mode = "ONE" ,score = 1*self.base_score}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		elseif obj.type == engine:getConstant("TYPE","AN_GANG") then
			local conf = {mode = "ALL",score = 2*self.base_score}
			engine:updateScoreFromConf(obj,conf,player.user_pos)
		end

		-- 暗杠锁死 ,锁死之后不能再点炮和抢杠胡
		if self.an_gang_suo_si then
			engine:updateConfig({isHu = false,qiangGangHu = false})
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
		self.gang_hua = self.gang_hua + 1
		--当第一次开杠或者补花时候，且荒庄数再往前移两张
		if self.gang_hua %2 == 1 then
			engine:setflowBureauNum(15)
		else
			engine:setflowBureauNum(14)
		end
		self:drawCard(player)
	end
 
	return "success"
end

--硬扣 硬扣之后只能自摸
game["YING_KOU"] = function(self,player,data)
	
	local obj = engine:checkHuCard(player.user_pos)
	if not obj then
		return "operator_error"
	end
	engine:setRecordData(player.user_pos,"yingkou",true)
	--通知所有人,有人硬扣
	local data = {user_pos=player.user_pos,card=obj.value}
	self.room:broadcastAllPlayers("notice_ying_kou",data)

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

	--如果是硬扣 则不能点炮胡和抢杠胡
	local yingkou = engine:getRecordData(player.user_pos,"yingkou")
	if yingkou then
		local num = engine:getHandleCardList(pos)
		if(num %3 ~= 2) then
			return "must_zimo"
		end
	end

	local obj,refResult = engine:huCard(player.user_pos,card)
	if not obj then
		return "operator_error"
	end
	

	--通知所有人,有人胡了
	local data = {user_id=player.user_id,user_pos=player.user_pos,item=obj}
	self.room:broadcastAllPlayers("notice_special_event",data)

	local hufen = self.base_score
	--硬扣+1 分
	if yingkou then
		hufen = hufen + 1
	end

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

	if self.qia_zhang and refResult.fans["DAN_DIAO"] then
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

	if refResult.isZiMo then
		local conf = {mode = "ALL" ,score = hufen,add = "pao_num",oneAdd="hua"}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
	else
		local conf = {mode = "ONE" ,score = hufen,add = "pao_num",oneAdd="hua"}
		engine:updateScoreFromConf(obj,conf,player.user_pos)
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
	local players = self.room.player_list
	-- 更新下明杠暗杠以及胡牌的计数
	for _,obj in ipairs(players) do
		obj.an_gang_num = engine:getTotalAnGangNum(obj.user_pos)
		obj.ming_gang_num = engine:getTotalMingGangNum(obj.user_pos)
		obj.hu_num = engine:getTotalHuNum(obj.user_pos)
	end

	--回合结束
	self.room:roundOver()

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
		--回合结束
		room:roundOver()
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

	--每个玩家出的牌
	rsp_msg.put_cards = {}
	rsp_msg.handle_nums = {}
	rsp_msg.four_card_list = self.four_card_list
	rsp_msg.ting_card = engine:getTing(player.user_pos)

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

	local ting_list = {}
	for pos=1,engine:getPlaceNum() do
		local ting = engine:getTing(pos) and true or false
		local temp = {user_pos=pos,ting = ting}
		table.insert(ting_list,temp)
	end
	
	rsp_msg.ting_list = ting_list

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
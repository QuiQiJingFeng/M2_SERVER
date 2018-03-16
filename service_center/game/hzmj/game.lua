local skynet = require "skynet"
local Room = require "Room"
local constant = require "constant"
local ALL_CARDS = constant.ALL_CARDS
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local GAME_CMD = constant.GAME_CMD
local NET_RESULT = constant.NET_RESULT
local PLAYER_STATE = constant.PLAYER_STATE
local ZJ_MODE = constant.ZJ_MODE
local PUSH_EVENT = constant.PUSH_EVENT
local GANG_TYPE = constant.GANG_TYPE
local GAME_OVER_TYPE = constant.GAME_OVER_TYPE
local cjson = require "cjson"
local judgecard = require "hzmj.judgecard"

local game = {}

local game_meta = {}
setmetatable(game,game_meta)
game.__index = game_meta
game.__newindex = game_meta

function game:clear()
	local game_meta = {}
	setmetatable(game,game_meta)
	game.__index = game_meta
	game.__newindex = game_meta
end

--洗牌  FisherYates洗牌算法
--算法的思想是每次从未选中的数字中随机挑选一个加入排列，时间复杂度为O(n)
function game:fisherYates()
	for i = #self.card_list,1,-1 do
		--在剩余的牌中随机取一张
		local j = math.random(i)
		--交换i和j位置的牌
		local temp = self.card_list[i]
		self.card_list[i] = self.card_list[j]
		self.card_list[j] = temp
	end

	if constant["DEBUG"] then
		self.card_list = require("hzmj/conf")
	end
end

--游戏结束
function game:gameOver(type)
	--游戏结束 计算玩家的积分
	if type == GAME_OVER_TYPE.NORMAL then
		--TODO
	end
	local info = self.room:getPlayerInfo("user_id","score","card_list")
	local data = {type = type,players = info}
	self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_GAME_OVER,data)
end

--检测流局
function game:flowBureau()
	local num = #self.card_list
	if num  == self.award_num + 1 then
		return true
	end

	return false
end

--游戏初始化
function game:init(room_info)
	self.room = Room.rebuild(room_info)
	local game_type = room_info.game_type
	--填充牌库
	self.card_list = {}
	local game_name = RECOVER_GAME_TYPE[game_type]
	for _,value in ipairs(ALL_CARDS[game_name]) do
		table.insert(self.card_list,value)
	end

	--洗牌
	self:fisherYates()

	self.other_setting = self.room:get("other_setting")
	--底分
	self.base_score = self.other_setting[1]
	--奖码数
	self.award_num = self.other_setting[2]
	--七对
	self.seven_pairs = self.other_setting[3]
	--喜分
	self.hi_point = self.other_setting[4]
	--一码不中当全中
	self.convert = self.other_setting[5]

	self.waite_operators = {}
	--当前出牌的位置
	self.cur_pos = nil
end

--更新庄家的位置
function game:updateZpos()
	local zpos = nil

	local zj_mode = self.room:get("zj_mode")
	local sit_down_num = self.room:get("sit_down_num")
	if not self.zpos then
		zpos = math.random(1,sit_down_num)
	else
		zpos = self.zpos
	end
	self.zpos = zpos
end
function game:start()
	--1、更新庄家的位置
	self:updateZpos()

	local players = self.room:get("players")
	--2、发牌
	local deal_num = 13 --红中麻将发13张牌
	local players = self.room:get("players")
	for index=1,self.room:get("sit_down_num") do
		local cards = {}
		for j=1,deal_num do
			--从最后一个开始移除,避免大量的元素位置重排
			local card = table.remove(self.card_list) 
			table.insert(cards,card)
		end

		local player = self.room:getPlayerByPos(index)
		player.card_list = cards
		local rsp_msg = {zpos = self.zpos,cards = cards}
		self.room:sendMsgToPlyaer(player,PUSH_EVENT.DEAL_CARD,rsp_msg)
	end

	--3、将card按类别和数字存储
	for _,player in ipairs(players) do
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
	
	for i,player in ipairs(players) do
		self.waite_operators[player.user_id] = "DEAL_FINISH"
	end
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
	print("card = >",card)

	for idx,value in ipairs(player.card_list) do
		if value == card then
			table.insert(indexs,idx)
		end
	end

	if #indexs < num then
		return false
	end
	for i,index in ipairs(indexs) do
		if i <= num then
			table.remove(player.card_list,index)
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

--通知玩家出牌
function game:noticePushPlayCard()
	local players = self.room:get("players")
	for i,player in ipairs(players) do
		local rsp_msg = {user_id=user_id}
		if player.user_id == user_id then
			rsp_msg.card_list = player.card_list
			rsp_msg.peng_list = player.card_stack["PENG"]
			rsp_msg.gang_list = player.card_stack["GANG"]
		end
		self.room:sendMsgToPlyaer(player,PUSH_EVENT.PUSH_PLAY_CARD,rsp_msg)
	end
end

--向A发一张牌 摸牌
function game:drawCard(player)
	--检查是否流局
	local is_flow = self:flowBureau()
	if is_flow then
		self.room:gameOver(GAME_OVER_TYPE.FLOW)
		return 
	end

	local card = table.remove(self.card_list)
	self:addHandleCard(player,card)
	local user_id = player.user_id

	--通知摸牌
	for _,obj in ipairs(self.room:get("players")) do
		local data = {user_id = user_id}
		if obj.user_id == user_id then
			data.card = card
		end
		self.room:sendMsgToPlyaer(obj,PUSH_EVENT.PUSH_DRAW_CARD,data)
	end

	--通知玩家出牌了
	self:noticePushPlayCard()

	self.waite_operators[player.user_id] = "PLAY_CARD"
end

--发牌完毕
game["DEAL_FINISH"] = function(self,player)

	local user_id = player.user_id
	if self.waite_operators[user_id] ~= "DEAL_FINISH" then
		return NET_RESULT.FAIL
	end
	self.waite_operators[user_id] = nil
	--计算剩余的数量
	local num = 0
	for k,v in pairs(self.waite_operators) do
		num = num + 1
	end

	if num == 0 then
		--庄家出牌
		local zplayer = self.room:getPlayerByPos(self.zpos)
		self:drawCard(zplayer)
	end
	return NET_RESULT.SUCCESS
end

--出牌
game["PLAY_CARD"] = function(self,player,data)
	if self.waite_operators[player.user_id] ~= "PLAY_CARD" then
		return NET_RESULT.FAIL
	end

	if not data.card then
		return NET_RESULT.FAIL
	end

	--减少A玩家的手牌
	local result = self:removeHandleCard(player,data.card)
	if not result then
		return NET_RESULT.NO_CARD
	end
	self.waite_operators[player.user_id] = nil

 	self.room:set("cur_card",data.card)
	self.cur_card = data.card

	local user_id = player.user_id
	local data = {user_id=user_id,card = data.card}
	--通知所有人 A 已经出牌
	self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_PLAY_CARD,data)

	self.cur_pos = palyer.user_pos

	local card_type = math.floor(data.card / 10) + 1
	local card_value = data.card % 10
	--因为红中麻将只能 抢杠胡(碰杠,先碰,然后自摸一个)和自摸胡,所以这里不用判断胡牌
	--只需要判断是否碰、杠 并且有且最多只有一个人会碰、杠


	local num = 0
	local check_player = nil
	local user_pos = player.user_pos
	for pos = user_pos+1,user_pos + self.room:get("seat_num")-1 do
		if pos > self.room:get("seat_num") then
			pos = 1
		end
		print('FYD++++++>POS = ',pos)
		check_player = self.room:getPlayerByPos(pos)
		local handle_cards = check_player.handle_cards

		num = handle_cards[card_type][card_value]
		if num == 2 then
			break
		elseif num == 3 then
			break
		end
	end
	
	if num == 2 then  --碰
		self.room:sendMsgToPlyaer(check_player,PUSH_EVENT.PUSH_OPERATOR_PALYER_STATE,{operator_state="PENG"})
		self.waite_operators[check_player.user_id] = "PENG"
	elseif num == 3 then  --杠
		self.room:sendMsgToPlyaer(check_player,PUSH_EVENT.PUSH_OPERATOR_PALYER_STATE,{operator_state="GANG"})
		self.waite_operators[check_player.user_id] = "GANG"
	else
		next_pos = user_pos + 1
		if next_pos > self.room:get("seat_num") then
			next_pos = 1
		end
		local next_player = self.room:getPlayerByPos(next_pos)
		self:drawCard(next_player)
	end


	return NET_RESULT.SUCCESS
end

function game:checkPeng(player,card)
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10
	local handle_cards = player.handle_cards
	return handle_cards[card_type][card_value] >= 2
end

--碰
game["PENG"] = function(self,player,data)
	if self.waite_operators[player.user_id] ~= "PENG" then
		return NET_RESULT.FAIL
	end
	self.waite_operators[player.user_id] = nil
	
	local card = self.room:get("cur_card")
	if not self:checkPeng(player,card) then
		return NET_RESULT.FAIL
	end

	local obj = {value = card}
	--记录下已经碰的牌
	table.insert(player.card_stack["PENG"],obj)

	--移除手牌
	local result = self:removeHandleCard(player,card,2)
	if not result then
		return NET_RESULT.FAIL
	end

	--通知所有人,有人碰了
	local data = {user_id=player.user_id,card = card}
	self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_PENG_CARD,data)

	--通知玩家出牌
	self:noticePushPlayCard()

	self.waite_operators[player.user_id] = "PLAY_CARD"

	return NET_RESULT.SUCCESS
end

function game:checkGang(player,card)
	--1、暗杠 手牌拥有四张牌
	--2、明杠 手牌拥有三张,加上别人出的一张
	--3、碰杠 手牌拥有1张
	local result
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10
	local handle_cards = player.handle_cards
	local num = handle_cards[card_type][card_value]
	if num >= 4 then
		result = GANG_TYPE.AN_GANG
	elseif num >= 3 then
		result = GANG_TYPE.MING_GANG
	elseif num == 1 then
		for _,obj in ipairs(player.card_stack["PENG"]) do
			if obj.value == card then
				result = GANG_TYPE.PENG_GANG
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
	return judgecard:JudgeIfHu2(player.handle_cards, tempResult, self.seven_pairs);
end

--杠
game["GANG"] = function(self,player,data)
	local card = data.card
	local gang_type = self:checkGang(player,card)
	if not gang_type then
		return NET_RESULT.FAIL
	end

	local operate = self.waite_operators[player.user_id]
	--如果操作是等待出牌,并且可以进行暗杠,则可以进去
	if operate == "PLAY_CARD" and gang_type == GANG_TYPE.AN_GANG then
	elseif operate ~= "GANG" then
		return NET_RESULT.FAIL
	end
	self.waite_operators[player.user_id] = nil

	

	local obj = {value = card,type = gang_type }
	--记录下已经杠的牌
	table.insert(player.card_stack["GANG"],obj)

	local num = 0
	if gang_type == GANG_TYPE.AN_GANG then
		num = 4
	elseif gang_type == GANG_TYPE.MING_GANG then
		num = 3
	elseif gang_type == GANG_TYPE.PENG_GANG then
		num = 1
	end
	--移除手牌
	local result = self:removeHandleCard(player,card,num)
	if not result then
		return NET_RESULT.FAIL
	end

	--通知所有人,有人杠了
	local data = {user_id = player.user_id,card = card,type=gang_type}
	self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_GANG_CARD,data)

	--如果不是碰杠,则不用检查是否有人胡牌
	if gang_type ~= GANG_TYPE.PENG_GANG then
		--杠了之后再摸一张牌
		self:drawCard(player)
		return NET_RESULT.SUCCESS
	end

	--检查是否有人胡这张牌
	local hu_list = {}
	local players = self.room:get("players")
	for _,temp_player in ipairs(players) do
		if temp_player.user_id ~= player.user_id then
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

	if #hu_list > 1 then
		for _,hu_player in ipairs(hu_list) do
			--通知客户端当前可以胡牌
	   		self.room:sendMsgToPlyaer(hu_player,PUSH_EVENT.PUSH_OPERATOR_PALYER_STATE,{operator_state = "HU"})
			self.waite_operators[player.user_id] = "HU"
		end
	else
	    --杠了之后再摸一张牌
		self:drawCard(player)
	end

	return NET_RESULT.SUCCESS
end

--过
game["GUO"] = function(self,player,data)
	local operate = self.waite_operators[player.user_id]
	if not operate then
		return NET_RESULT.FAIL
	end
	self.waite_operators[player.user_id] = nil
	--下一家出牌
	local next_pos = self.cur_pos + 1
	if next_pos > self.room:get("seat_num") then
		next_pos = 1
	end
	local next_player = self.room:getPlayerByPos(next_pos)
	self:drawCard(next_player)
	return NET_RESULT.SUCCESS
end


--胡牌
game["HU"] = function(self,player,data)
	local operate = self.waite_operators[player.user_id]
	if not (operate == "PLAY_CARD" or operate == "HU") then
		return NET_RESULT.FAIL
	end
	self.waite_operators[player.user_id] = nil

	--检查是否有人胡这张牌
 	local card = self.room:get("cur_card")
	--胡牌前,先将这张杠牌加入玩家手牌
	self:addHandleCard(player,card)
	local is_hu = self:checkHu(player)
	--检查完之后,去掉这张牌
	self:removeHandleCard(player,card,1)
	if is_hu then
		self.room:gameOver(GAME_OVER_TYPE.NORMAL)
	end
	return NET_RESULT.SUCCESS
end

function game:gameCMD(data)
	local user_id = data.user_id
	local command = data.command
	local func = game[command]
	if not func then
		return NET_RESULT.NOSUPPORT_COMMAND
	end

	local player = self.room:getPlayerByUserId(user_id)
	local result = func(game,player,data)
	return result
end

return game
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

local judgecard = require "judgecard"

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
end

--游戏初始化
function game:init(room_info)
	self.room = Room.rebuild(room_info)
	local game_type = room_info.game_type
	--填充牌库
	self.card_list = {}
	game_type = RECOVER_GAME_TYPE[game_type]
	print("FYD++++>game_type = ",game_type)
	for _,value in ipairs(ALL_CARDS[game_type]) do
		table.insert(self.card_list,value)
	end

	--洗牌
	self:fisherYates()
end

--更新庄家的位置
function game:updateZpos()
	local zpos = nil

	local zj_mode = self.room:get("zj_mode")
	local sit_down_num = self.room:get("sit_down_num")
	if zj_mode == ZJ_MODE.YING_ZHUANG then
		if not self.zpos then
			zpos = math.random(1,sit_down_num)
		else
			zpos = self.zpos
		end
	elseif zj_mode == ZJ_MODE.LIAN_ZHUANG then
		if not self.zpos then
			zpos = math.random(1,sit_down_num)
		else
			zpos = (self.zpos + 1) % sit_down_num
		end
	end
	self.zpos = zpos
end

function game:start()
	--1、更新庄家的位置
	self:updateZpos()

	local players = self.room:get("players")
	local cjson = require "cjson"
	print("PLAYER = cjson =-",cjson.encode(players))
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

	--等待玩家发牌完毕
	print("等待玩家发牌完毕")
end

--增加手牌
function game:addHandleCard(player,card)

	table.insert(player.card_list,card)
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10

	local all_card = player.all_card
	all_card[card_type][10] = all_card[card_type][10] + 1
	all_card[card_type][card_value] = all_card[card_type][card_value] + 1
end

--减去手牌
function game:removeHandleCard(player,card)
	local index = false
	for idx,value in ipairs(player.card_list) do
		if value == card then
			index = idx
			break
		end
	end

	if not index then
		return false
	end
	table.remove(player.card_list,index)
	local card_type = math.floor(card / 10) + 1
	local card_value = card % 10
	local all_card = player.all_card
	all_card[card_type][10] = all_card[card_type][10] - 1
	all_card[card_type][card_value] = all_card[card_type][card_value] - 1
	return true
end

--向A发一张牌 摸牌
function game:pushCard(player)

	local card = table.remove(self.card_list)
	self:addHandleCard(player,card)

	local user_id = player.user_id
	local rsp_msg = {user_id = user_id,card = card}

	--通知摸牌
	self.room:broadcastAllPlayers(PUSH_EVENT.PUSH_CARD,rsp_msg)
end


--发牌完毕
game["DEAL_FINISH"] = function(user_id)
	print("1111111 user_id = ",user_id)
	local all = game.room:updatePlayerState(user_id,PLAYER_STATE.DEAL_FINISH)
	if all then
		print("FYD++++++发牌完毕,A出牌")
	end
	print("222222")
end

function game:gameCMD(data)
	print("FYD++++++GMCOMD  user_id = ",user_id)
	local user_id = data.user_id
	local command = data.command
	local func = game[command]
	if not func then
		return NET_RESULT.NOSUPPORT_COMMAND
	end
	func(user_id)
	return NET_RESULT.SUCCESS
end
 





















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
	return judgecard:JudgeIfHu2(player.all_card, tempResult, false);
end



function game:checkPeng(player,card)
	local card_type = math.floor(value / 10) + 1
	local card_value = value % 10
	local all_card = player.all_card
	return all_card[card_type][card_value] >= 2
end

function game:checkGang(card)
	local card_type = math.floor(value / 10) + 1
	local card_value = value % 10
	local all_card = player.all_card
	return all_card[card_type][card_value] >= 3
end

--处理客户端出牌
function game:chuPai(player,card)
	local wait_users = self.room:get("wait_users")
	if not wait_users[player.user_id] then
		return "invailed_user_id"
	end

	--减少A玩家的手牌
	local result = self:removeHandleCard(player,card)
	if not result then
		return "no_card"
	end

	wait_users[player.user_id] = nil

	self.room:set("cur_card",card)

	local user_id = player.user_id
	--通知BCD A 已经出牌
	self.room:broadcastOtherPlayers(user_id,PUSH_EVENT.NOTICE_CHU_PAI,{user_id = user_id,card=card})

	local is_in = false
	local record = self.room:get("record")
	--推送BCD 通知他们 当前是否可以进行 碰、杠、胡
	local place_num = self.room:get("place_number")
	for i =1,place_num - 1 do
		local next_pos = (player.user_pos + i) % place_num
		next_pos = next_pos == 0 and 1 or next_pos
		local next_player = self.room:getPlayerByPos(pos)
		local hu = self:checkHu(next_player)
		local peng = self:checkPeng(next_player)
		local gang = self:checkGang(next_player)
		if hu or peng or gang then
			if hu then table.insert(record[OPERATER.HU],next_player.user_id) end
			if peng then table.insert(record[OPERATER.PENG],next_player.user_id) end
			if gang then table.insert(record[OPERATER.GANG],next_player.user_id) end
			record["operaters"][next_player.user_id] = "NONE"
			is_in = true
			wait_users[next_player.user_id] = true
			--通知玩家BCD  碰、杠、胡的状态
			self.room:sendMsgToPlyaer(next_player,PUSH_EVENT.NOTICE_PLAYER_STATE,{hu=hu,peng=peng,gang=gang})
		end
	end
	--如果没有人 胡、碰、杠,则下家为出牌
	if not is_in then
		local next_pos = (player.user_pos + i) % place_num
		next_pos = next_pos == 0 and 1 or next_pos
		local next_player = self.room:getPlayerByPos(pos)
		self:pushCard(next_player)
	end
	return "success"
end

--处理客户端胡牌
function game:huPai(player)
	local wait_users = self.room:get("wait_users")
	if not wait_users[player.user_id] then
		return "invailed_user_id"
	end

	local record = self.room:get("record")
	local index
	for idx,user_id in ipairs(record[OPERATER.HU]) do
		if user_id == player.user_id then
			index = idx
		end
	end

	if not index then
		return "cannot_hu"
	end

	wait_users[player.user_id] = nil

	record["operaters"][player.user_id] = OPERATER.HU

	--如果是胡牌,那么判断是否在队列的第一个,如果是,则结束牌局
	if index == 1 then
		--TODO  GAME OVER  
		local user_id = player.user_id
		self.room:clearRecord()
		return "success"
	else
		--胡队列中位于 A 玩家之前的玩家ID列表
		local pre_user_ids = {}
		local place_num = self.room:get("place_number")
		for i=1,place_num - 2 do
			local pre_index = index - i
			if pre_index >= 1 then
				local pre_user_id = record[OPERATER.HU][pre_index]
				table.insert(pre_user_ids,pre_user_id)
			end
		end
		
		local can_hu = true
		--如果A玩家之前的玩家 已经操作完毕并且没有选择胡，则本次胡牌成功
		for i,pre_user_id in ipairs(pre_user_ids) do
			local operate = record["operaters"][pre_user_id]
			if operate ~= "NONE" and operate ~= OPERATER.HU then
				can_hu = can_hu and true
			else
				can_hu = can_hu and false
			end
		end
		
		if can_hu then
			--TODO GAME OVER
			local list = {}
			for _,player in ipairs(self.room:get("players")) do
				local user_id = player.user_id
				local score = player.score
				local card_list = player.card_list
				local item = {user_id = user_id,score = score,card_list=card_list}
				table.insert(list,item)
			end

			local user_id = player.user_id
			list.user_id = user_id
			self.room:clearRecord()
			--结束游戏 通知本局积分情况
			self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_GAME_OVER,list)
			return "success"
		else
			--已经记录 无法立即处理
			return "cord_command"
		end
	end

	return "success"
end

--碰
function game:pengPai(player)
	local wait_users = self.room:get("wait_users")
	if not wait_users[player.user_id] then
		return "invailed_user_id"
	end

	local record = self.room:get("record")
	local index
	for idx,user_id in ipairs(record[OPERATER.PENG]) do
		if user_id == player.user_id then
			index = idx
		end
	end

	if not index then
		return "cannot_peng"
	end

	wait_users[player.user_id] = nil
	record["operaters"][player.user_id] = OPERATER.PENG	


	--碰牌的时候 需要先检查后面有没有胡
	local user_pos = player.user_pos

	local last_user_ids = {}
	local num = self.room:get("place_number")
	for i = 1,num -1 do
		local pos = (user_pos + i) % 4
		pos = pos == 0 and 1 or pos
		local player = self.room:getPlayerByPos(pos)
		table.insert(last_user_ids,player.user_id)
	end

	local hu_user_id = nil
	for _,user_id in ipairs(last_user_ids) do
		 for _,id in ipairs(record[OPERATER.HU]) do
		 	if user_id == id then
		 		hu_user_id = user_id
		 		break
		 	end
		 end
		if hu_user_id then
			break
		end
	end

	--如果后面有胡
	if hu_user_id then
		--TODO GAMEOVER  通知胡牌
		local list = {}
		for _,player in ipairs(self.room:get("players")) do
			local user_id = player.user_id
			local score = player.score
			local card_list = player.card_list
			local item = {user_id = user_id,score = score,card_list=card_list}
			table.insert(list,item)
		end

		local user_id = player.user_id
		list.user_id = user_id
		self.room:clearRecord()
		--结束游戏 通知本局积分情况
		self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_GAME_OVER,list)
		--本次碰牌失败
		return "fail"
	else
		local card = self.room:get("cur_card")
		--否则执行碰牌
		for i=1,2 do
			local result = self:removeHandleCard(player,card)
			if not result then
				return "no_card"
			end
		end
		self.room:clearRecord()
		return "success"
	end
	return "success"
end

--杠牌
function game:gangPai(player)
	local wait_users = self.room:get("wait_users")
	if not wait_users[player.user_id] then
		return "invailed_user_id"
	end

	local record = self.room:get("record")
	local index
	for idx,user_id in ipairs(record[OPERATER.GANG]) do
		if user_id == player.user_id then
			index = idx
		end
	end

	if not index then
		return "cannot_gang"
	end

	wait_users[player.user_id] = nil
	record["operaters"][player.user_id] = OPERATER.GANG	


	--杠牌的时候 需要先检查后面有没有胡
	local user_pos = player.user_pos

	local last_user_ids = {}
	local num = self.room:get("place_number")
	for i = 1,num -1 do
		local pos = (user_pos + i) % 4
		pos = pos == 0 and 1 or pos
		local player = self.room:getPlayerByPos(pos)
		table.insert(last_user_ids,player.user_id)
	end

	local hu_user_id = nil
	for _,user_id in ipairs(last_user_ids) do
		 for _,id in ipairs(record[OPERATER.HU]) do
		 	if user_id == id then
		 		hu_user_id = user_id
		 		break
		 	end
		 end
		if hu_user_id then
			break
		end
	end

	--如果后面有胡
	if hu_user_id then
		--TODO GAMEOVER  通知胡牌
		local list = {}
		for _,player in ipairs(self.room:get("players")) do
			local user_id = player.user_id
			local score = player.score
			local card_list = player.card_list
			local item = {user_id = user_id,score = score,card_list=card_list}
			table.insert(list,item)
		end

		local user_id = player.user_id
		list.user_id = user_id
		self.room:clearRecord()
		--结束游戏 通知本局积分情况
		self.room:broadcastAllPlayers(PUSH_EVENT.NOTICE_GAME_OVER,list)
		--本次杠牌失败
		return "fail"
	else
		local card = self.room:get("cur_card")
		--否则执行杠牌
		for i=1,3 do
			local result = self:removeHandleCard(player,card)
			if not result then
				return "no_card"
			end
		end
		self.room:clearRecord()
		return "success"
	end
	return "success"
end

return game
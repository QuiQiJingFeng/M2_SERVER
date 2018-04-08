local skynet = require "skynet"
local Room = require "Room"
local constant = require "constant"
local log = require "skynet.log"
local cluster = require "skynet.cluster"
local utils = require "utils"
local ALL_CARDS = constant.ALL_CARDS
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local GAME_CMD = constant.GAME_CMD
local NET_RESULT = constant.NET_RESULT
local ZJ_MODE = constant.ZJ_MODE
local PUSH_EVENT = constant.PUSH_EVENT

local PAY_TYPE = constant.PAY_TYPE
local ROUND_COST = constant.ROUND_COST

local cjson = require "cjson"
local judgecard = require "hzmj.judgecard"

local GANG_TYPE = {
	AN_GANG = 1,
	MING_GANG = 2,
	PENG_GANG = 3,
}
local GAME_OVER_TYPE = {
	["NORMAL"] = 1, --正常胡牌
	["FLOW"] = 2,	--流局
	["DISTROY_ROOM"] = 3,   --房间解散推送结算积分
}

local TYPE = {
	PENG = 1,
	GANG = 2,
	CHI = 3,
}

local game = {}

local game_meta = {}
setmetatable(game,game_meta)
game.__index = game_meta
game.__newindex = game_meta

function game:clear()

	local players = self.room:get("players")
	local over_round = self.room:get("over_round")
	local round = self.room:get("round")
	-- 大赢家金币结算
	if over_round >= 1 then
		local pay_type = self:get("pay_type")
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
				local gold_num = self:safeClusterCall(obj.node_name,".agent_manager","updateResource",obj.user_id,"gold_num",-1*per_cost)
				obj.gold_num = gold_num
				local info = {user_id=obj.user_id,user_pos=obj.user_pos,gold_num=gold_num}
				table.insert(gold_list,info)
			end
			self:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end
	end

	--如果在1局跟最后一局之间解散的,则需要发送结算通知
	if over_round >= 1 and over_round < round then
		self:gameOver(player,GAME_OVER_TYPE.DISTROY_ROOM)
	end
	

	--清空数据
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

function game:safeClusterCall(node_name,service_name,func,...)
    local result,rsp = xpcall(cluster.call,debug.traceback,node_name,service_name,func,...)
    if not result then
    	log.warning("cluster call faild")
    end
    return rsp
end

--更新玩家的积分
function game:updatePlayerScore(player,over_type,operate,tempResult)
	local players = self.room:get("players")
	local seat_num = self.room:get("seat_num")
	local award_list = {}
	if over_type == GAME_OVER_TYPE.NORMAL then
		local count = seat_num - 1
		--如果是自摸胡  赢每个玩家2*底分
		if operate == "WAIT_PLAY_CARD" then
			player.cur_score = player.cur_score + self.base_score * 2 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2
				end
			end
		end

		--摸到四张红中胡牌，赢每个玩家2*底分；
		if tempResult.iHuiNum == 4 then
			player.cur_score = player.cur_score + self.base_score * 2 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2
				end
			end
		end

 		--胡七对 赢每个玩家2*底分
		if tempResult.iChiNum + tempResult.iPengNum == 0 then
			player.cur_score = player.cur_score + self.base_score * 2 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2
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
		if num > 0 then
			player.cur_score = player.cur_score + self.base_score * 2 * 2 * num * count 
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2 * 2 * num
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
		for _,player in ipairs(players) do
			for i,obj in ipairs(player.card_stack) do
				if obj.type == TYPE.GANG then
					if obj.gang_type == GANG_TYPE.AN_GANG then
						player.an_gang_num = player.an_gang_num + 1
					else
						player.ming_gang_num = player.ming_gang_num + 1
					end
				end
			end
			player.reward_num = player.reward_num + 1
			player.card_stack = {}
		end
	end

	local info = self.room:getPlayerInfo("user_id","score","card_list","user_pos","cur_score")
	local data = {over_type = over_type,players = info,award_list=award_list}

	if over_type == GAME_OVER_TYPE.NORMAL then
		data.winner_pos = player.user_pos
		if operate == "WAIT_PLAY_CARD" then
			data.winner_type = constant["WINNER_TYPE"].ZIMO
		elseif operate == "WAIT_HU" then
			data.winner_type = constant["WINNER_TYPE"].QIANG_GANG
		end
	end
	local cur_round = self.room:get("cur_round")
	local round = self.room:get("round")
	data.last_round = cur_round == round

	self.room:broadcastAllPlayers("notice_game_over",data)

	self.room:set("players",players)
end

--更新玩家的金币
function game:updatePlayerGold(over_type)
	if over_type == GAME_OVER_TYPE.DISTROY_ROOM then
		return 
	end
	local room = self.room
	local players = room:get("players")
	local cur_round = room:get("cur_round")
	local round = room:get("round")
	local seat_num = room:get("seat_num")

	--花费
	local cost = round * ROUND_COST
	--出资类型
	local pay_type = room:get("pay_type")
	--第一局结束 结算(房主出资/平摊出资)的金币
	if cur_round == 1 then
		--房主出资
		if pay_type == PAY_TYPE.ROOM_OWNER_COST then
			local owner_id = room:get("owner_id")
			local owner = room:getPlayerByUserId(owner_id)
			--更新玩家的金币数量
			local gold_num = self:safeClusterCall(owner.node_name,".agent_manager","updateResource",owner_id,"gold_num",-1*cost)
			--如果owner不存在 有可能不在游戏中(比如:有人开房给别人玩,自己不玩)
			if owner then
				owner.gold_num = gold_num
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
				local gold_num = self:safeClusterCall(obj.node_name,".agent_manager","updateResource",obj.user_id,"gold_num",-1*per_cost)
				obj.gold_num = gold_num
				local info = {user_id = obj.user_id,user_pos = obj.user_pos,gold_num = gold_num}
				table.insert(gold_list,info)
			end
			room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end   
	end
end

--游戏结束
function game:gameOver(player,over_type,operate,tempResult)

	local room = self.room
	local players = room:get("players")
	local cur_round = room:get("cur_round")
	local round = room:get("round")
	local seat_num = room:get("seat_num")
	local room_id = room:get("room_id")

	--计算金币并通知玩家更新
	self:updatePlayerGold(over_type)

	--计算积分并通知玩家
	self:updatePlayerScore(player,over_type,operate,tempResult)

	--FYD1
	--更新当前已经完成的局数
	local over_round = self.room:get("over_round")
	self.room:set("over_round",over_round + 1)


	local players = self.room:get("players")
	for i,player in ipairs(players) do
		player.is_sit = nil
	end
	self.room:set("players",self.room:get("players"))

	skynet.call(".room_manager","lua","gameOver",room_id)
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
function game:init(room_id,gtype)

	self.room = Room.recover("room:"..room_id)

	--填充牌库
	self.card_list = {}
	for _,value in ipairs(ALL_CARDS[gtype]) do
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

	--等待玩家操作的列表
	self.waite_operators = {}
	--当前出牌人
	self.cur_play_user = nil
	--当前出的牌
	self.cur_play_card = nil

	local players = self.room:get("players")
	for _,player in ipairs(players) do
		--玩家当前局积分清零
		player.cur_score = 0
	end	
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

	if constant["DEBUG"] then
		local conf = require("hzmj/conf")
		self.zpos = conf.zpos
		utils:mergeToTable(self.card_list,conf.card_list)
	end

	local players = self.room:get("players")
	local random_nums = {}
	for i = 1,2 do
		local num = math.random(1,6)
		table.insert(random_nums,num)
	end

	--2、发牌
	local deal_num = 13 --红中麻将发13张牌
	for index=1,self.room:get("sit_down_num") do
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
		rsp_msg.cur_round = self.room:get("cur_round")

		self.room:sendMsgToPlyaer(player, "deal_card", rsp_msg)
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
		self.waite_operators[player.user_pos] = "WAIT_DEAL_FINISH"
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

--通知玩家出牌
function game:noticePushPlayCard(splayer,operator)
	local players = self.room:get("players")
	for i,player in ipairs(players) do
		local rsp_msg = {user_id=splayer.user_id,user_pos=splayer.user_pos}
		if player.user_id == splayer.user_id then
			rsp_msg.card_list = player.card_list
			rsp_msg.card_stack = player.card_stack
		end
		rsp_msg.operator = operator
		self.room:sendMsgToPlyaer(player,"push_play_card",rsp_msg)
	end
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
	for _,obj in ipairs(self.room:get("players")) do
		local data = {user_id = user_id,user_pos = player.user_pos}
		if obj.user_id == user_id then
			data.card = card
		end

		self.room:sendMsgToPlyaer(obj,"push_draw_card",data)
	end

	--通知玩家出牌了
	local operator = 1
	self:noticePushPlayCard(player,operator)

	self.waite_operators[player.user_pos] = "WAIT_PLAY_CARD"
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

	if num > 0 then
		--庄家出牌
		local zplayer = self.room:getPlayerByPos(self.zpos)
		self:drawCard(zplayer)

	end
	return "success"
end

--出牌
game["PLAY_CARD"] = function(self,player,data)
	if self.waite_operators[player.user_pos] ~= "WAIT_PLAY_CARD" then
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
		self.room:sendMsgToPlyaer(check_player,"push_player_operator_state",{operator_list=operator_list,user_pos=check_player.user_pos,card=data.card})
		self.waite_operators[check_player.user_pos] = "WAIT_PENG"
	elseif num == 3 then  --杠
		table.insert(operator_list,"PENG")
		table.insert(operator_list,"GANG")
		self.room:sendMsgToPlyaer(check_player,"push_player_operator_state",{operator_list=operator_list,user_pos=check_player.user_pos,card=data.card})
		self.waite_operators[check_player.user_pos] = "WAIT_GANG_WAIT_PENG"
	else
		next_pos = user_pos + 1
		if next_pos > self.room:get("seat_num") then
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

	self.room:broadcastAllPlayers("notice_peng_card",data)

	--通知玩家出牌
	local operator = 2
	self:noticePushPlayCard(player,operator)

	self.waite_operators[player.user_pos] = "WAIT_PLAY_CARD"

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
		result = GANG_TYPE.AN_GANG
	elseif num >= 3 then
		result = GANG_TYPE.MING_GANG
	elseif num == 1 then
		for _,obj in ipairs(player.card_stack) do
			if obj.value == card and obj.type == TYPE.PENG then
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
	if operate == "WAIT_PLAY_CARD" and (gang_type == GANG_TYPE.AN_GANG or gang_type == GANG_TYPE.PENG_GANG ) then
	elseif not string.find(self.waite_operators[player.user_pos],"WAIT_GANG") then
		return "invaild_operator"
	end

	self.waite_operators[player.user_pos] = nil

	local obj = {value = card,gang_type = gang_type,type=TYPE.GANG}
	local num = 0
	if gang_type == GANG_TYPE.AN_GANG then
		obj.from = player.user_pos
		num = 4
		--记录下已经杠的牌
		table.insert(player.card_stack,obj)
	elseif gang_type == GANG_TYPE.MING_GANG then
		obj.from = self.cur_play_user.user_pos
		num = 3
		--记录下已经杠的牌
		table.insert(player.card_stack,obj)
	elseif gang_type == GANG_TYPE.PENG_GANG then
		num = 1
		--如果是碰杠,则更改碰变成杠
		for _,item in ipairs(player.card_stack) do
			if item.value == card and item.type == TYPE.PENG then
				item.type = TYPE.GANG
				item.gang_type = GANG_TYPE.PENG_GANG
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

	self.room:broadcastAllPlayers("notice_gang_card",data)


	local players = self.room:get("players")
	local count = self.room:get("seat_num") - 1

	local origin_data = self.room:getPlayerInfo("user_id","cur_score")

	--计算杠的积分
	for _,obj in ipairs(player.card_stack) do
		if obj.gang_type == GANG_TYPE.AN_GANG then
			--暗杠，赢每个玩家2*底分；
			player.cur_score = player.cur_score + self.base_score * 2 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 2
				end
			end
		elseif obj.gang_type == GANG_TYPE.MING_GANG then
			--明杠 赢放杠者3*底分
			player.cur_score = player.cur_score + self.base_score * 3
			for _,obj in ipairs(players) do
				if obj.from == obj.user_pos then
					obj.cur_score = obj.cur_score - self.base_score * 3
				end
			end
		elseif obj.gang_type == GANG_TYPE.PENG_GANG then
			--自己摸的明杠(公杠) 三家出，赢每个玩家1*底分；
			player.cur_score = player.cur_score + self.base_score * 1 * count
			for _,obj in ipairs(players) do
				if player.user_id ~= obj.user_id then
					obj.cur_score = obj.cur_score - self.base_score * 1
				end
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

	if gang_type ~= GANG_TYPE.PENG_GANG then
		--杠了之后再摸一张牌
		self:drawCard(player)
		return "success"
	end
	--如果是碰杠,则需要检查是否有人胡这张牌
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
	   		self.room:sendMsgToPlyaer(hu_player,"push_player_operator_state",{operator_state = "HU",user_pos = hu_player.user_pos,user_id=hu_player.user_id})
			self.waite_operators[player.user_pos] = "WAIT_HU"
			self.gang_pos = player.user_pos
		end
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

	--检测是否有延迟胡牌的情况
	local positions = {}
	for pos,v in pairs(self.waite_operators) do
		table.insert(positions,pos)
	end

	if #positions >= 1 then
		for i=1,self.room:get("seat_num")-1 do
			local next_pos = self.gang_pos + 1
			if positions[next_pos] then  --找到胡牌人中优先级最高的人
				if positions[next_pos] == "DELAY_HU" then --如果这个人处于延迟胡状态
					local player = self.room:getPlayerByPos(next_pos)
					local is_hu,tempResult = self:checkHu(player)
					if is_hu then
						--延迟胡牌不可能是自摸胡牌,所以这里填写WAIT_HU
						self:gameOver(player,GAME_OVER_TYPE.NORMAL,"WAIT_HU",tempResult)
					end
				end
			end
		end
	end
		
	--下一家出牌
	local next_pos = self.cur_play_user.user_pos + 1
	if next_pos > self.room:get("seat_num") then
		next_pos = 1
	end
	local next_player = self.room:getPlayerByPos(next_pos)
	self:drawCard(next_player)
	return "success"
end


--胡牌
game["HU"] = function(self,player,data)
	local operate = self.waite_operators[player.user_pos]
	local gang_hu = string.find(self.waite_operators[player.user_pos],"WAIT_HU")

	if not (operate == "WAIT_PLAY_CARD" or gang_hu) then
		return "invaild_operator"
	end

	local positions = {}
	for pos,v in pairs(self.waite_operators) do
		positions[pos] = true
	end
	if # positions > 1 then
		for i=1,self.room:get("seat_num")-1 do
			local next_pos = self.gang_pos + 1
			if positions[next_pos] then  --找到胡牌人中优先级最高的人,如果当前胡牌人不是这个人
				if positions[next_pos] ~= player.user_pos then
					--延迟胡牌
					self.waite_operators[player.user_pos] = "DELAY_HU"
					return "success"
				end
			end
		end
	end

	self.waite_operators[player.user_pos] = nil


	--抢杠的话，杠是不算的
	if gang_hu then
		local card = nil
		for _,obj in ipairs(player.card_stack) do
			if obj.gang_type == GANG_TYPE.PENG_GANG then
				obj.gang_type = nil
				obj.type = TYPE.PENG
				card = obj.value
			end
		end
		--胡牌前,先将这张杠牌加入玩家手牌
		self:addHandleCard(player,card)
		local is_hu = self:checkHu(player)
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

--返回房间
game["BACK_ROOM"] = function(self,player,data)
	player.fd = data.fd
	local room_setting = self.room:getPropertys("game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting","cur_round")

	local players_info = self.room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit","score","card_stack","gold_num")
	local rsp_msg = {}
	rsp_msg.room_setting = room_setting
	rsp_msg.card_list = player.card_list
	rsp_msg.players = players_info
	rsp_msg.operator = self.waite_operators[player.user_pos]

	self.room:sendMsgToPlyaer(player,"push_all_room_info",rsp_msg)

	self.room:noticePlayerConnectState(player,true)
	return "success"
end

function game:gameCMD(data)
	local user_id = data.user_id
	local command = data.command
	local func = game[command]
	if not func then
		return "no_support_command"
	end

	local player = self.room:getPlayerByUserId(user_id)
	local result = func(game,player,data)
	return result
end

return game

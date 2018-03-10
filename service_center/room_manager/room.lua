local cluster = require "skynet.cluster"
local constant = require "constant"
local PLAYER_STATE = constant["PLAYER_STATE"]
local ZJ_MODE = constant["ZJ_MODE"]
local ALL_GAME_NUMS = constant["ALL_GAME_NUMS"]
local ALL_ZJ_MODE = constant["ALL_ZJ_MODE"]
local ALL_CARDS = constant.constant["ALL_CARDS"]
local ALL_DEAL_NUM = constant["ALL_DEAL_NUM"]
local ALL_COMMAND = constant["ALL_COMMAND"]
local OPERATER = constant["OPERATER"]
local PUSH_EVENT = constant["PUSH_EVENT"]
local Room = {}

Room.__index = Room

function Room.new(room_id,node_name)
	local new_room = setmetatable({ property = {}}, room)
	new_room.__index = room
	new_room:init(room_id,node_name)

	return new_room
end
--使用数据重建房间,因为虚拟机之间只能传递数据,所以需要重新构建
function Room.rebuild(property)
	local new_room = setmetatable({ property = property}, room)
	new_room.__index = room
	return new_room
end

function Room:init(room_id,node_name)
	--房间ID
	self.property.room_id = room_id
	--房间所在的服务器地址
	self.property.node_name = node_name
	--房间中的玩家列表
	self.property.players = {}

	--房间中 已经准备的玩家数量
	self.property.prepare_num = 0
	--房间中 发牌动画完毕的玩家数量
	self.property.finish_deal_num = 0
	--游戏房间的地址
	self.property.service_id = nil
	--游戏的类型
	self.property.game_type = nil
	--房间座位的数量
	self.property.place_number = 0
	--房间座位
	self.property.palces = {}
	--庄家模式
	self.property.zj_mode = nil
	--当前庄家
	self.property.cur_zhuang_pos = nil
	--牌池
	self.property.card_list = {}
	--发牌的数量
	self.property.deal_num = nil
	--支持的命令
	self.property.commands = {}
	--当前出的牌
	self.property.cur_card = nil
	--等待玩家操作
	self.property.wait_users = {}
	--按顺序记录所有可以胡牌/碰牌、杠牌的ID
	self.property.record = {[OPERATER.HU]={},[OPERATER.PENG]={},[OPERATER.GANG]={},operaters={}}

end

--清空记录
function Room:clearRecord()
	self.property.record = {[OPERATER.HU]={},[OPERATER.PENG]={},[OPERATER.GANG]={},operaters={}}
end



--设置游戏房间地址
function Room:setServiceId(service_id)
	self.property.service_id = service_id
end

--设置游戏的类型
function Room:setGameType(game_type)
	self.property.game_type = game_type
	self.property.place_number = ALL_GAME_NUMS[game_type]
	for i=1,self.property.place_number do
		self.property.palces[i] = false
	end

	self.property.zj_mode = ALL_ZJ_MODE[game_type]
	self.property.deal_num = ALL_DEAL_NUM[game_type]
	self.property.commands = ALL_COMMAND[game_type]
	for _,value in ipairs(ALL_CARDS[game_type]) do
		table.insert(self.property.card_list,value)
	end
end

function Room:isSuportCommand(command)
	for _,cmd in ipairs(self.property.commands) do
	   if cmd == command then
	      return true
	   end
	end
	return false
end

--洗牌  FisherYates洗牌算法
--算法的思想是每次从未选中的数字中随机挑选一个加入排列，时间复杂度为O(n)
function Room:fisherYates()
	for i = #self.card_list,1,-1 do
		--在剩余的牌中随机取一张
		local j = math.random(i)
		--交换i和j位置的牌
		local temp = self.card_list[i]
		self.card_list[i] = self.card_list[j]
		self.card_list[j] = temp
	end
end

--发牌
function Room:dealCards()
	local zhuang_pos = nil

	local zj_mode = self.property.zj_mode
	local cur_zhuang_pos = self.property.cur_zhuang_pos
	local place_number = self.property.place_number
	if zj_mode == ZJ_MODE.YING_ZHUANG then
		if not cur_zhuang_pos then
			zhuang_pos = math.random(1,place_number)
		else
			zhuang_pos = cur_zhuang_pos
		end
	elseif zj_mode == ZJ_MODE.LIAN_ZHUANG then
		if not cur_zhuang_pos then
			zhuang_pos = math.random(1,place_number)
		else
			zhuang_pos = (cur_zhuang_pos + 1) % place_number
		end
	end

	local players = self.property.players
	for index=1,self.property.place_number do
		local cards = {}
		for j=1,self.property.deal_num do
			local card = table.remove(self.property.card_list)
			table.insert(cards,card)
		end
		local player = players[index]
		player.card_list = cards
		local rsp_msg = {zhuang_pos = zhuang_pos,cards = cards}
		self.room:sendMsgToPlyaer(player,PUSH_EVENT.DEAL_CARD,rsp_msg)
	end
end

function Room:getPlayerByPos(pos)
	for _,player in ipairs(self.property.players) do
		if pos == player.user_pos then
			return player
		end
	end
end

function Room:getPlayerByUserId(user_id)
	for _,player in ipairs(self.property.players) do
		if user_id == player.user_id then
			return player
		end
	end
end

--添加玩家
function Room:addPlayer(user_id,user_name,user_pic,node_name,service_id)
	
	local player = {}
	--玩家的ID
	player.user_id = user_id
	--玩家的名称
	player.user_name = user_name
	--玩家头像的url
	player.user_pic = user_pic
	--玩家所在游戏服的地址
	player.node_name = node_name
	--玩家服务的地址
	player.service_id = service_id
	--积分
	player.score = 0
	--玩家状态初始化
	player.state = PLAYER_STATE.UN_PREPARE
	--玩家位置 选择一个没有被占用的位置设置为玩家的位置
	local pos 
	for index,value in ipairs(self.property.palces) do
		if not value then
			pos = index
			break
		end
	end
	player.user_pos = pos
	--玩家手里的牌
	player.card_list = {}

	table.insert(self.property.players,player)
end

--游戏开始的时候按照位置进行排序一次  出牌顺序为
function Room:sortPlayers()
	table.sort(self.property.players,function(a,b) 
			return a.user_pos < b.user_pos
		end)
end

--获取房间的属性
function Room:get(property_name)
	return self.property[property_name]
end

function Room:set(property_name,value)
	self.property[property_name] = value
end

--获取所有玩家的 ID 名称 头像 状态数据
function Room:getPlayerInfo(...)
	local filters = {...}
	local info = {}
	for _,player in ipairs(self.property.players) do
		local temp = {}
		for _,key in ipairs(filters) do
			temp[key] = player[key]
		end
		table.insert(info,temp)
	end
	return info
end

function Room:getAllInfo()
	return self.property
end

function Room:getOtherPlayer(except_user_id)
	local players = {}
	for _,player in ipairs(self.property.players) do
		if player.user_id ~= except_user_id then
			table.insert(players,player)
		end
	end
	return players
end

function Room:removePlayer(user_id)
	for index,player in ipairs(self.property.players) do
		if player.user_id == user_id then
			--清空座位
			self.property.palces[player.user_pos] = false
			table.remove(self.property.players,index)
			break
		end
	end
end

--更新玩家的状态 并且返回是否已经坐满人
function Room:updatePlayerState(user_id,new_state)
	for index,player in ipairs(self.property.players) do
		if player.user_id == user_id then
				palyer.state = new_state
				if new_state == PLAYER_STATE.PREPARE_FINISH then
					self.property.prepare_num = self.property.prepare_num + 1
					return self.property.prepare_num == self.property.place_number
				elseif new_state == PLAYER_STATE.DEAL_FINISH then
					self.property.finish_deal_num = self.property.finish_deal_num + 1
					return self.property.finish_deal_num == self.property.place_number
				end
			break
		end
	end

	
end

--广播消息
function Room:broadcastAllPlayers(msg_name,msg_data)
	for _,player in ipairs(self.property.players) do
		local node_name = player.node_name
		local service_id = player.service_id
		local success = pcall(cluster.call,node_name, service_id, "push",msg_name,msg_data)
		if not success then
			print("ERROR: 网络错误,center服向游戏服发送信息失败")
		end
	end
end

--广播消息
function Room:broadcastOtherPlayers(except_user_id,msg_name,msg_data)
	local players = self:getOtherPlayer(except_user_id)
	self:broadcastAllPlayers(players,msg_name,msg_data)
end

--向某个人发送消息
function Room:sendMsgToPlyaer(player,msg_name,msg_data)
	local node_name = player.node_name
	local service_id = player.service_id
	local success = pcall(cluster.call,node_name, service_id, "push",msg_name,msg_data)
	if not success then
		print("ERROR: 网络错误,center服向游戏服发送信息失败")
	end	
end

--清理房间
function Room:clear()
	--清空所有的属性
	self.property = {}
end

return Room
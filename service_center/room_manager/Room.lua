local cluster = require "skynet.cluster"
local constant = require "constant"
local PLAYER_STATE = constant["PLAYER_STATE"]
local ZJ_MODE = constant["ZJ_MODE"]
local ALL_GAME_NUMS = constant["ALL_GAME_NUMS"]
local ALL_ZJ_MODE = constant["ALL_ZJ_MODE"]
local ALL_CARDS = constant["ALL_CARDS"]
local ALL_DEAL_NUM = constant["ALL_DEAL_NUM"]
local ALL_COMMAND = constant["ALL_COMMAND"]
local OPERATER = constant["OPERATER"]
local PUSH_EVENT = constant["PUSH_EVENT"]

local RECOVER_GAME_TYPE = constant["RECOVER_GAME_TYPE"]

local Room = {}

Room.__index = Room

function Room.new(room_id,node_name)
	local new_room = { property = {}}
	setmetatable(new_room, Room)
	new_room.__index = Room
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
	--坐下的人数
	self.property.sit_down_num = 0
	--发牌完毕的玩家数量
	self.property.finish_deal_num = 0
end

function Room:setInfo(info)
	self.property.game_type = info.game_type
	self.property.round = info.round
	self.property.pay_type = info.pay_type
	self.property.seat_num = info.seat_num
	self.property.is_friend_room = info.is_friend_room
	self.property.is_open_voice = info.is_open_voice
	self.property.is_open_gps = info.is_open_gps
	self.property.other_setting = info.other_setting

	--庄家模式
	self.property.zj_mode = ALL_ZJ_MODE[RECOVER_GAME_TYPE[info.game_type]]
end

--设置游戏房间地址
function Room:setServiceId(service_id)
	self.property.service_id = service_id
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
function Room:addPlayer(info)
	local player = {}
	--玩家的ID
	player.user_id = info.user_id
	--玩家的名称
	player.user_name = info.user_name
	--玩家头像的url
	player.user_pic = info.user_pic
	--玩家IP
	player.user_ip = info.user_ip
	--玩家所在游戏服的地址
	player.node_name = info.node_name
	--玩家服务的地址
	player.service_id = info.service_id
	--积分
	player.score = 0
	--玩家状态初始化
	player.state = PLAYER_STATE.UN_SIT_DOWN
	
	table.insert(self.property.players,player)
end

--获取房间的属性
function Room:get(property_name)
	return self.property[property_name]
end

function Room:set(property_name,value)
	self.property[property_name] = value
end

function Room:getPropertys(...)
	local args = {...}
	local info = {}
	for i,v in ipairs(args) do
		info[v] = self.property[v]
	end
	return info
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

function Room:updatePlayerProperty(user_id,name,value)
	for index,player in ipairs(self.property.players) do
		if player.user_id == user_id then
			player[name] = value
			return true
		end
	end
	return false
end

--更新玩家的状态 并且返回是否已经坐满人
function Room:updatePlayerState(user_id,new_state)
	local result = self:updatePlayerProperty(user_id,"state",new_state)
	if result then
		if new_state == PLAYER_STATE.SIT_DOWN_FINISH then
			self.property.sit_down_num = self.property.sit_down_num + 1
			return self.property.sit_down_num == self.property.seat_num
		elseif new_state == PLAYER_STATE.DEAL_FINISH then
			self.property.finish_deal_num = self.property.finish_deal_num + 1
			return self.property.finish_deal_num == self.property.seat_num
		end
	end	
end

--广播消息
function Room:broadcastAllPlayers(msg_name,msg_data)
	for _,player in ipairs(self.property.players) do
		local node_name = player.node_name
		local service_id = player.service_id
		print("PUSH:",node_name,service_id,"push",msg_name,msg_name)
		cluster.call(node_name, service_id, "push",msg_name,msg_data)
	end
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
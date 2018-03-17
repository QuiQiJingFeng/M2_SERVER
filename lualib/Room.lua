local skynet = require "skynet"
local cluster = require "skynet.cluster"
local constant = require "constant"
local log = require "skynet.log"
local cjson = require "cjson"

local ZJ_MODE = constant["ZJ_MODE"]
local ALL_GAME_NUMS = constant["ALL_GAME_NUMS"]
local ALL_ZJ_MODE = constant["ALL_ZJ_MODE"]
local ALL_CARDS = constant["ALL_CARDS"]
local ALL_DEAL_NUM = constant["ALL_DEAL_NUM"]
local ALL_COMMAND = constant["ALL_COMMAND"]
local OPERATER = constant["OPERATER"]
local PUSH_EVENT = constant["PUSH_EVENT"]

local RECOVER_GAME_TYPE = constant["RECOVER_GAME_TYPE"]
local REDIS_DB = 2
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
	local new_room = { property = property}
	setmetatable(new_room, Room)
	new_room.__index = Room
	return new_room
end

function Room:init(room_id,node_name)
	--房间ID
	self:set("room_id",room_id)
	--房间所在的服务器地址
	self:set("node_name",node_name)
	--房间中的玩家列表
	self:set("players",{})
	--坐下的人数
	self:set("sit_down_num",0)
	--当前出牌值
	self:set("cur_card",nil)
	--点击重新开始的人数
	self:set("restart_num",0)
	--房间的状态
	self:set("state",constant.ROOM_STATE.GAME_PREPARE)

	--将房间号加到房间列表中,并且和服务器名称绑定到一起
	skynet.call(".redis_center","lua","HSET",REDIS_DB,"room_list",room_id,node_name)
end

function Room:setInfo(info)
	self:set("game_type",info.game_type)
	self:set("round",info.round)
	self:set("pay_type",info.pay_type)
	self:set("seat_num",info.seat_num)
	self:set("is_friend_room",info.is_friend_room)
	self:set("is_open_voice",info.is_open_voice)
	self:set("is_open_gps",info.is_open_gps)
	self:set("other_setting",info.other_setting)
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
	
	--记录已经碰或者杠的牌
	player.card_stack = { PENG = {},GANG = {}}
	player.handle_cards = {}
	table.insert(self.property.players,player)
	player.user_pos = #self.property.players
	player.is_sit = false
	player.isconnect = true
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
			table.remove(self.property.players,index)
			local sit_down_num = self:get("sit_down_num")
			self:set("sit_down_num",sit_down_num-1)
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

--像游戏服推送消息
function Room:pushEvent(node_name,service_id,msg_name,msg_data)
	local success = xpcall(cluster.call, debug.traceback, node_name, service_id, "push", msg_name, msg_data)
	if not success then
		log.infof("向游戏服[%s]推送消息[%s]失败\n内容如下:\n%s",cjson.encode(msg_data))
	end	
end

--广播消息
function Room:broadcastAllPlayers(msg_name,msg_data)
	for _,player in ipairs(self.property.players) do
		if player.isconnect then
			local node_name = player.node_name
			local service_id = player.service_id
			self:pushEvent(node_name,service_id,msg_name,msg_data)
		end
	end
end

--向某个人发送消息
function Room:sendMsgToPlyaer(player,msg_name,msg_data)
	if player.isconnect then
		local node_name = player.node_name
		local service_id = player.service_id
		self:pushEvent(node_name,service_id,msg_name,msg_data)
	end
end

--清理房间
function Room:distroy()
	local room_id = self:get("room_id")
	local service_id = self:get("service_id")
	local node_name = self:get("node_name")
	--删除掉房间列表中的房间号
	skynet.call(".redis_center","lua","HDEL",REDIS_DB,"room_list",room_id)
	--清理房间服务的数据
	skynet.call(service_id,"lua","clear")
	--还原初始的属性
	self.property = {service_id=service_id,node_name=node_name}
	log.infof("房间%d被销毁",room_id)
end

return Room
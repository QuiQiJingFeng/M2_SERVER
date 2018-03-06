local skynet = require "skynet"
local redis = require "skynet.db.redis"
local INIT_NUM = 100

local room_pool = {}
--[[
	room = {
		room_id 房间编号,玩家可以通过该编号加入房间
		service_id 棋局服务的地址
		node_name 棋局服务器结点名称,通过该名称,可以从游戏服向中心服发送消息
		players  房间中玩家的信息
	}

	player = {
		user_id 玩家的ID
		user_name 玩家的名称
		node_name  游戏服务器结点名称,通过该名称,可以从棋局服务器向游戏服务器推送消息
		service_id 通过该service_id 可以向游戏服务器的玩家服务推送消息
	}
]]

function room_pool:init()
	local center_redis_address = skynet.getenv("center_redis")
    local address, port = string.match(center_redis_address, "([%d%.]+):([%d]+)")
    self.center_redis = redis.connect({ host = address, port = port })
    --空闲的房间列表
    self.unused_list = {}
    --正在使用的房间列表
    self.used_list = {}
    --预分配一组空闲的房间
    self:preAllocRoom()
end

--预申请一部分房间
function room_pool:preAllocRoom()
    self.center_redis:set("room_id_generator",INIT_NUM)
	for id = 1,INIT_NUM do
		self:allocRoom(id)
	end
end

--申请一个房间
function room_pool:allocRoom(room_id)
	if not room_id then
		room_id = self.center_redis:incrby("room_id_generator",1)
	end
	local node_name = skynet.getenv("node_name")
	local room = { room_id = room_id, node_name = node_name, players = {}, prepare_num = 0}
	room.service_id = skynet.newservice("game")

	table.insert(self.unused_list,room)

	--设置绑定关系,通过room_id可以查到棋局服务器结点进而可以发送消息过来
	self.center_redis:hset("room_list",room.room_id,node_name)

	return room
end

--获取一个未使用的空房间
function room_pool:getUnusedRoom()
	if #self.unused_list > 0 then
		local room = table.remove(self.unused_list,1)
		room.prepare_num = 0
		table.insert(self.used_list,room)
		return room
	else
		return self:allocRoom()
	end
end

--清理指定的房间
function room_pool:cleanTargetRoom(room_id)
	for idx,room in ipairs(self.used_list) do
		if room.room_id == room_id then
			local room = table.remove(self.used_list,idx)
			skynet.call(room.service_id,"lua","clean")
			table.insert(self.unused_list,room)
		end
	end
end

--自动清理房间 当房间里面一个人也没有的时候执行清理操作
function room_pool:autoCleanRoom()
	local will_remove = {}
	for idx,room in ipairs(self.used_list) do
		if #room.players <= 0 then
			table.insert(will_remove,idx)
		end
	end

	for idx = #will_remove,1,-1 do
		local room = table.remove(self.used_list,idx)
		skynet.call(room.service_id,"lua","clean")
		table.insert(self.unused_list,room)
	end
end

function room_pool:getRoomByRoomID(room_id)
	for _,room in ipairs(self.used_list) do
		if room.room_id == room_id then
			return room
		end
	end
	return nil
end

return room_pool
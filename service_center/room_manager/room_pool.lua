local skynet = require "skynet"
local redis = require "skynet.db.redis"

local INIT_NUM = 10
local room_pool = {}

function room_pool:createNewRoom()
	local room = { players = {} }
	room.service_id = skynet.newservice("game")
	table.insert(self.unused_pool,room)

	room.room_id = string.format("%d-%d",skynet.getenv("center_server_id"),room.service_id)
	--存储room_id 跟 node_name 的对应关系,这样玩家可以通过room_id查到对应的node_name
	self.center_redis:hset("room_list",room.room_id,skynet.getenv("node_name"))

	return room
end

function room_pool:init()
	local center_redis_address = skynet.getenv("center_redis")
    local address, port = string.match(center_redis_address, "([%d%.]+):([%d]+)")
    self.center_redis = redis.connect({ host = address, port = port })

	self.unused_pool = {}
	self.use_pool = {}
	for id = 1,INIT_NUM do
		self:createNewRoom()
	end
end

function room_pool:getUnusedRoom()
	local room = table.remove(self.unused_pool,1)
	if not room then
		room = self:createNewRoom()
	end
	table.insert(self.use_pool,room)
	return room
end

function room_pool:cleanRoom(room_id)
	local index = nil
	for idx,room in ipairs(self.use_pool) do
		if room.room_id == room_id then
			index = idx
			break
		end
	end
	skynet.call(room.service_id,"lua","CleanData")
	--重新放入回收池
	local room = table.remove(self.use_pool,index)
	room.owner_id = nil
	room.players = {}
	table.insert(self.unused_pool,room)
end

function room_pool:getRoomByRoomID(room_id)
	for _,room in ipairs(self.use_pool) do
		if room.room_id == room_id then
			return room
		end
	end
	return nil
end


return room_pool
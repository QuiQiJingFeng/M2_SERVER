local skynet = require "skynet"

local Room = require "Room"
local RedisManager = require "RedisManager"
local CENTER_REDIS
local INIT_NUM = 100

local RoomPool = {}

function RoomPool:init()
    CENTER_REDIS = RedisManager:connectCenterRedis()
    --空闲的房间列表
    self.unused_list = {}
    --正在使用的房间列表
    self.used_list = {}
    --预分配一组空闲的房间
    self:preAllocRoom()
end

-----------------------------内部方法 BEGIN-----------------------
--申请一个房间
function RoomPool:allocRoom(room_id)
	if not room_id then
		room_id = CENTER_REDIS:incrby("room_id_generator",1)
	end
	local node_name = skynet.getenv("node_name")
	local room = Room.new(room_id,node_name)
	local service_id = skynet.newservice("game")
	room:setServiceId(service_id)
	table.insert(self.unused_list,room)

	return room
end

--预申请一部分房间
function RoomPool:preAllocRoom()
	--每次Center服启动的时候,重新设置room_id_generator
    CENTER_REDIS:set("room_id_generator",INIT_NUM)
	for id = 1,INIT_NUM do
		self:allocRoom(id)
	end
end

--绑定房间ID 和 服务器地址
function RoomPool:bindRoomIdToServer(room_id)
	CENTER_REDIS:hset("room_list",room_id,node_name)
end
-----------------------------内部方法 END-----------------------


-----------------------------外部接口 BEGIN---------------------------
--获取一个空闲的空房间
function RoomPool:getUnusedRoom()
	local room
	if #self.unused_list > 0 then
		room = table.remove(self.unused_list,1)
		table.insert(self.used_list,room)
	else
		room = self:allocRoom()
	end
	--将房间绑定到服务器地址
	self:bindRoomIdToServer(room:get("room_id"))
	return room
end

--清理指定的房间
function RoomPool:cleanRoom(room_id)
	for idx,room in ipairs(self.used_list) do
		if room:get("room_id") == room_id then
			local room = table.remove(self.used_list,idx)
			local service_id = room:get("service_id")
			skynet.call(service_id,"lua","clear")
			table.insert(self.unused_list,room)
			break
		end
	end
end

--通过room_id 来获取room
function RoomPool:getRoomByRoomID(room_id)
	for _,room in ipairs(self.used_list) do
		if room.get("room_id") == room_id then
			return room
		end
	end
end
-----------------------------外部接口 END
---------------------------
return RoomPool
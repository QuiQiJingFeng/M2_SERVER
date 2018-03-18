local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local Room = require "Room"
local server_info = sharedata.query("server_info")
local utils = require "utils"

local INIT_NUM = 100
local REDIS_DB = 2
local RoomPool = {}

function RoomPool:init()
    --空闲的房间列表
    self.unused_list = {}
    --正在使用的房间列表
    self.used_list = {}

    --每隔1分钟检查一下失效的房间
    shield.timeout(60 * 100, utils:handler(self,checkExpireRoom))
end

function RoomPool:checkExpireRoom()
	local now = skynet.time()
	for i=#self.used_list,1,-1 do
		local room = self.used_list[i]
		local sit_down_num = room:get("sit_down_num")
		--如果房间没人,则30分钟后销毁房间
		local expire_time = room:get("expire_time")
		if expire_time and now > expire_time then
			room:distroy()
			table.remove(self.used_list,i)
			table.insert(self.unused_list,room)
		end
	end
end

function RoomPool:distroyRoom(room_id)
	for i=#self.used_list,1,-1 do
		local room = self.used_list[i]
		if room_id == room:get("room_id") then
			room:distroy()
			table.remove(self.used_list,i)
			table.insert(self.unused_list,room)
			break
		end
	end
end

function RoomPool:getUnusedRandomId()
	local pre_id = math.random(1,9)
	local last_id = string.format("%05d",math.random(0,99999)) 
	local random_id = tonumber(pre_id..last_id)

	local ret = skynet.call(".redis_center","lua","SISMEMBER",REDIS_DB,"room_pool",random_id)
	if ret == 1 then
		return self:getUnusedRandomId()
	else
		skynet.call(".redis_center","lua","SADD",REDIS_DB,"room_pool",random_id)
		return random_id
	end
end

-----------------------------内部方法 BEGIN-----------------------
--申请一个房间
function RoomPool:allocRoom(room_id)
	local room_id = self:getUnusedRandomId()
	local node_name = server_info.node_name
	local room = Room.new(room_id,node_name)
	local service_id = skynet.newservice("game")
	room:setServiceId(service_id)

	return room
end

-----------------------------内部方法 END-----------------------


-----------------------------外部接口 BEGIN---------------------------
--获取一个空闲的空房间
function RoomPool:getUnusedRoom()
	local room
	if #self.unused_list > 0 then
		room = table.remove(self.unused_list,1)
	else
		room = self:allocRoom()
	end
	table.insert(self.used_list,room)
	return room
end

--通过room_id 来获取room
function RoomPool:getRoomByRoomID(room_id)
	for _,room in ipairs(self.used_list) do
		if room:get("room_id") == room_id then
			return room
		end
	end
end
-----------------------------外部接口 END
---------------------------
return RoomPool
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local server_info = sharedata.query("server_info")
local constant = require "constant"
local Room = require "Room"
local utils = require "utils"
local REDIS_DB = 2
local RoomPool = {}

--获取一个唯一的房间号ID
local function getUnusedRandomId()
	local pre_id = math.random(1,9)
	local last_id = string.format("%05d",math.random(0,99999)) 
	local random_id = tonumber(pre_id..last_id)

	local ret = skynet.call(".redis_center","lua","SISMEMBER",REDIS_DB,"room_pool",random_id)
	if ret == 1 then
		return getUnusedRandomId()
	else
		skynet.call(".redis_center","lua","SADD",REDIS_DB,"room_pool",random_id)
		return random_id
	end
end

function RoomPool:init()
    --空闲的房间列表
    self.unused_list = {}
    --正在使用的房间map
    self.used_map = {}

    self:recovery()

    --每隔1分钟检查一下失效的房间
    self:checkExpireRoom()
end

function RoomPool:checkExpireRoom()
	local cord_list = {}
	local now = skynet.time()
	for room_id,room in pairs(self.used_map) do
		local expire_time = room:get("expire_time")
		if expire_time and now > expire_time then
			table.insert(cord_list,room_id)
		end
	end

	for _,room_id in ipairs(cord_list) do
		self:distroyRoom(room_id,constant.DISTORY_TYPE.EXPIRE_TIME)
	end

	--每隔1分钟检查一下失效的房间
    skynet.timeout(60 * 100, utils:handler(self,self.checkExpireRoom))
end

--恢复已有的房间
function RoomPool:recovery()
    local room_keys = skynet.call(".redis_center","lua","GetRoomKeysForNodeName",REDIS_DB,server_info.node_name)
    for _,room_key in pairs(room_keys) do
    	local room = Room.recover(room_key)
    	local service_id = skynet.newservice("game")
    	room:set("service_id",service_id)
    	print("恢复房间 id = ",room:get("room_id"))
    	self.used_map[room:get("room_id")] = room
    end
end

--销毁房间 type 1、房间的过期时间到了 
function RoomPool:distroyRoom(room_id,type)
	local room = self.used_map[room_id]
	room:broadcastAllPlayers("notice_player_distroy_room",{room_id=room_id,type=type})

	self.used_map[room_id] = nil
	table.insert(self.unused_list,room)
	room:distroy()
	skynet.send(".redis_center","lua","SREM",REDIS_DB,"room_pool",room_id)
end

function RoomPool:getRoomByRoomID(room_id)
	return self.used_map[room_id]
end

function RoomPool:allocRoom()
	local room_id = getUnusedRandomId()
	local node_name = server_info.node_name
	local service_id = skynet.newservice("game")
	local room = Room.new(room_id,node_name,service_id)

	return room
end

--获取一个空闲的空房间
function RoomPool:getUnusedRoom()
	local room
	if #self.unused_list > 0 then
		local index 
		for idx,_ in pairs(self.unused_list) do
			index = idx
			break
		end
		room = table.remove(self.unused_list,index)
		local room_id = getUnusedRandomId()
		room:reuse(room_id)
	else
		room = self:allocRoom()
	end

	self.used_map[room:get("room_id")] = room
	return room
end

return RoomPool
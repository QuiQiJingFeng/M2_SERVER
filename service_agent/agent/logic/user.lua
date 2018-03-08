local skynet = require "skynet"
local utils = require "utils"
local event_handler = require "event_handler"
local cluster = require "skynet.cluster"
local json = require "cjson"
local user_info = require "user_info"

local user = {}

function user:init()
    event_handler:on("create_room",utils:handler(self,user.createRoom))
    event_handler:on("join_room",utils:handler(self,user.joinRoom))
end

--创建房间
function user:createRoom(req_msg)
	local room_id = user_info:hgetData(user_info._user_info_key,"room_id")
	if room_id then
		return "create_room",{result="already_create_room"}
	end
	local user_id = user_info._user_id
	local node_name = skynet.getenv("node_name")
	local service_id = skynet.self()

	local target_node = cluster.call("common_server", ".cluster_manager", "pickNode", "center_server")
	local result,rsp_msg = cluster.call(target_node,".room_manager","createRoom",user_id,"幼儿园一把手",node_name,service_id)
	rsp_msg.result = result
	user_info._room_id = rsp_msg.room_id
	--绑定room_id
	user_info:hsetData(user_info._user_info_key,"room_id",rsp_msg.room_id)
	return "create_room",rsp_msg
end

--加入房间
function user:joinRoom(req_msg)
	local room_id = user_info:hgetData(user_info._user_info_key,"room_id")
	if room_id then
		return "create_room",{result="aready_join_room"}
	end
	local room_id = req_msg.room_id
	local user_id = user_info._user_id
	local node_name = skynet.getenv("node_name")
	local service_id = skynet.self()
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	local result,rsp_msg = cluster.call(target_node,".room_manager","joinRoom",room_id,user_id,"幼儿园一把手",node_name,service_id)
	rsp_msg.result = result
	user_info._room_id = rsp_msg.room_id
	user_info:hsetData(user_info._user_info_key,"room_id",rsp_msg.room_id)

	return "join_room",rsp_msg
end

--离开房间
function user:leaveRoom()
	local result = user_info:leaveRoom()
	return "leaveRoom",{result = result}
end

--准备
function user:prepare()
	local room_id = user_info._room_id
	local user_id = user_info._user_id
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	local result = cluster.call(target_node,".room_manager","prepare",room_id,user_id)
	return "prepare",{result = result}
end

--开始游戏 --房主操作
function user:startGame(req_msg)
	local room_id = req_msg.room_id
	local user_id = user_info._user_id
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	local result = cluster.call(target_node,".room_manager","startGame")
	return "startGame",{result = result}
end


return user
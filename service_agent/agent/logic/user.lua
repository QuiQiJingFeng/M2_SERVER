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

function user:battleProto(req_msg)

end

--创建房间
function user:createRoom(req_msg)
	local room_id = user_info:hgetData(user_info._user_info_key.."room_list","room_id")
	if room_id then
		return "create_room",{result="当前已经绑定有房间号,是否进入该房间"}
	end
	local user_id = user_info._user_id
	local source_node = skynet.getenv("node_name")
	local service_adress = skynet.self()
	local target_node = cluster.call("common_server", ".cluster_manager", "pickNode", "center_server")
	local rsp_msg = cluster.call(target_node,".room_manager","createRoom",user_id,"幼儿园一把手",source_node,service_adress)
	rsp_msg.result = "success"
	user_info._room_id = rsp_msg.room_id
	--绑定room_id
	user_info:hsetData(user_info._user_info_key.."room_list","room_id",rsp_msg.room_id)
	return "create_room",rsp_msg
end

--加入房间
function user:joinRoom(req_msg)
	local room_id = user_info:hgetData(user_info._user_info_key.."room_list","room_id")
	if room_id then
		return "create_room",{result="当前已经绑定有房间号,是否进入该房间"}
	end
	local room_id = req_msg.room_id
	local user_id = user_info._user_id
	local source_node = skynet.getenv("node_name")
	local service_adress = skynet.self()
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	local rsp_msg = cluster.call(target_node,".room_manager","joinRoom",user_id,"幼儿园一把手",room_id,source_node,service_adress)
	rsp_msg.result = "success"
	user_info._room_id = rsp_msg.room_id
	user_info:hsetData(user_info._user_info_key.."room_list","room_id",rsp_msg.room_id)

	return "join_room",rsp_msg
end

--离开房间
function user:leaveRoom(req_msg)
	local room_id = req_msg.room_id
	local user_id = user_info._user_id
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	cluster.call(target_node,".room_manager","leaveRoom",room_id,user_id)
	return "leaveRoom",{result = "success"}
end

--准备
function user:prepare(req_msg)
	local room_id = req_msg.room_id
	local user_id = user_info._user_id
	local target_node = user_info:getTargetNodeByRoomId(room_id)
	cluster.call(target_node,".room_manager","prepare",room_id,user_id)
	return "prepare",{result = "success"}
end

--开始游戏 --房主操作
function user:startGame()

end


return user
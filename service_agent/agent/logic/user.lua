local skynet = require "skynet"
local utils = require "utils"
local event_handler = require "event_handler"
local cluster = require "skynet.cluster"
local user_info = require "user_info"

local constant = require "constant"
local NET_EVENT = constant.NET_EVENT
local NET_RESULT = constant.NET_RESULT

local user = {}

function user:init()
    event_handler:on(NET_EVENT.CREATE_ROOM,utils:handler(self,user.createRoom))
    event_handler:on(NET_EVENT.JOIN_ROOM,utils:handler(self,user.joinRoom))
    event_handler:on(NET_EVENT.PREPARE,utils:handler(self,user.prepare))
    event_handler:on(NET_EVENT.FINISH_DEAL,utils:handler(self,user.finishDeal))
    event_handler:on(NET_EVENT.LEAVE_ROOM,utils:handler(self,user.leaveRoom))
    event_handler:on(NET_EVENT.GAME_CMD,utils:handler(self,user.gameCmd))
    
end

--创建房间
function user:createRoom(req_msg)
	local room_id = user_info:hgetData(user_info.user_info_key,"room_id")
	if room_id then  
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.ALREADY_IN_ROOM}
	end
	local user_id = user_info.user_id
	local node_name = skynet.getenv("node_name")
	local service_id = skynet.self()

	local center_node = cluster.call("common_server", ".cluster_manager", "pickNode", "center_server")
	local data = {}
	data.game_type = req_msg.game_type
	data.user_id = user_id
	data.user_name = user_info.user_name
	data.user_pic = user_info.user_pic
	data.node_name = node_name
	data.service_id = service_id

	local result,rsp_msg = cluster.call(center_node,".room_manager","createRoom",data)
	rsp_msg.result = result
	--绑定room_id
	user_info:hsetData(user_info.user_info_key,"room_id",rsp_msg.room_id)

	return NET_EVENT.CREATE_ROOM,rsp_msg
end

--加入房间
function user:joinRoom(req_msg)
	local room_id = user_info:hgetData(user_info.user_info_key,"room_id")
	if room_id then
		return NET_EVENT.JOIN_ROOM,{result = NET_RESULT.ALREADY_IN_ROOM}
	end
	local room_id = req_msg.room_id
	print("FYD+++room_id = ",room_id)
	local user_id = user_info.user_id
	local node_name = skynet.getenv("node_name")
	local service_id = skynet.self()
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.JOIN_ROOM,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end
	local data = {}
	data.game_type = req_msg.game_type
	data.user_id = user_id
	data.user_name = user_info.user_name
	data.user_pic = user_info.user_pic
	data.node_name = node_name
	data.service_id = service_id
	data.room_id = room_id

	local result,rsp_msg = cluster.call(center_node,".room_manager","joinRoom",data)
	rsp_msg.result = result
	if result == NET_RESULT.SUCCESS then
		user_info:hsetData(user_info.user_info_key,"room_id",rsp_msg.room_id)
	end

	return NET_EVENT.JOIN_ROOM,rsp_msg
end

--离开房间
function user:leaveRoom()
	local result = user_info:leaveRoom()
	return NET_EVENT.LEAVE_ROOM,{result = result}
end

--准备
function user:prepare()
	local room_id = user_info.room_id
	local user_id = user_info.user_id
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.PREPARE,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end
	local result = cluster.call(center_node,".room_manager","prepare",room_id,user_id)
	return NET_EVENT.PREPARE,{result = result}
end

--发牌完毕
function user:dealFinish()
	local room_id = user_info.room_id
	local user_id = user_info.user_id
	local data = {room_id = room_id,user_id = user_id}
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.FINISH_DEAL,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end
	local result = cluster.call(center_node,".room_manager","dealFinish",data)
	return NET_EVENT.FINISH_DEAL,{result = result}
end

--游戏命令 
function user:gameCmd(data)
	local room_id = user_info.room_id
	local user_id = user_info.user_id

	data.user_id = user_id
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.GAME_CMD,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end
	local result = cluster.call(center_node,".room_manager","gameCmd",data)

	return NET_EVENT.GAME_CMD,{result=result}
end


return user
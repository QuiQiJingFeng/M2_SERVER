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
	local room_id = user_info:getCurrentRoomId()
	if room_id then  
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.ALREADY_IN_ROOM}
	end

	local center_node = user_info:getCenterNode()
	if not center_node then
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.FAIL}
	end

	local data = user_info:getValues("user_id","user_name","user_pic")
	data.node_name = user_info.node_name
	data.service_id = user_info.service_id
	data.user_ip = user_info.user_ip

	for k,v in pairs(data) do
		req_msg[k] = v
	end

	local success,result,rsp_msg = user_info:safeClusterCall(center_node,".room_manager","createRoom",req_msg)
	if not success then
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.FAIL}
	end
	rsp_msg.result = result

	user_info:set("room_id",rsp_msg.room_id)

	return NET_EVENT.CREATE_ROOM,rsp_msg
end

--加入房间
function user:joinRoom(req_msg)
	local room_id = user_info:getCurrentRoomId()
	if room_id then  
		return NET_EVENT.JOIN_ROOM,{result = NET_RESULT.ALREADY_IN_ROOM}
	end

	local room_id = req_msg.room_id
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.JOIN_ROOM,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end

	local data = user_info:getValues("user_id","user_name","user_pic")
	data.node_name = user_info.node_name
	data.service_id = user_info.service_id
	data.user_ip = user_info.user_ip

	local success,result,rsp_msg = user_info:safeClusterCall(center_node,".room_manager","joinRoom",req_msg)
	if not success then
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.FAIL}
	end
	rsp_msg.result = result
	if result == NET_RESULT.SUCCESS then
		user_info:set("room_id",room_id)
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
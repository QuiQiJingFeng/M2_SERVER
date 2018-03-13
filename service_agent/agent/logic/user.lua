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
    event_handler:on(NET_EVENT.SIT_DOWN,utils:handler(self,user.sitDown))
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

	local success,result,room_id = user_info:safeClusterCall(center_node,".room_manager","createRoom",req_msg)
	if not success then
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.FAIL}
	end

	user_info:set("room_id",room_id)

	return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.SUCCESS}
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

	for k,v in pairs(data) do
		req_msg[k] = v
	end

	local success,result = user_info:safeClusterCall(center_node,".room_manager","joinRoom",req_msg)
	if not success then
		return NET_EVENT.CREATE_ROOM,{result = NET_RESULT.FAIL}
	end
 
	if result == NET_RESULT.SUCCESS then
		user_info:set("room_id",room_id)
	end

	return NET_EVENT.JOIN_ROOM,{result = NET_RESULT.SUCCESS}
end

--离开房间
function user:leaveRoom()
	local result = user_info:leaveRoom()
	return NET_EVENT.LEAVE_ROOM,{result = result}
end

--入座
function user:sitDown(req_msg)
	print("FDY USER 1111111111")
	local room_id = user_info:getCurrentRoomId()
	if not room_id then  
		return NET_EVENT.SIT_DOWN,{result = NET_RESULT.NOT_EXIST_ROOM}
	end
	print("FDY USER 22222222222222")
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.SIT_DOWN,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end
	print("FDY USER 3333333333333")
	local data = user_info:getValues("user_id")
	data.room_id = room_id
	data.pos = req_msg.pos

	local success,result = user_info:safeClusterCall(center_node,".room_manager","sitDown",data)
	if not success then
		return NET_EVENT.SIT_DOWN,{result = NET_RESULT.FAIL}
	end

	return NET_EVENT.SIT_DOWN,{result = result}
end

--游戏命令 
function user:gameCmd(data)
	local room_id = user_info:getCurrentRoomId()
	if not room_id then  
		return NET_EVENT.GAME_CMD,{result = NET_RESULT.NOT_EXIST_ROOM}
	end
 
	local center_node = user_info:getTargetNodeByRoomId(room_id)
	if not center_node then
		return NET_EVENT.GAME_CMD,{result = NET_RESULT.NOT_EXIST_ROOM}  
	end

	data.user_id = user_info:get("user_id")
	data.room_id = room_id
	local success,result = user_info:safeClusterCall(center_node,".room_manager","gameCMD",data)
	if not success then
		return NET_EVENT.SIT_DOWN,{result = NET_RESULT.FAIL}
	end

	return NET_EVENT.GAME_CMD,{result=result}
end


return user
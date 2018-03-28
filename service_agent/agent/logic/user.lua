local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"
local utils = require "utils"
local event_handler = require "event_handler"
local user_info = require "user_info"
local cjson = require "cjson"
local constant = require "constant"
local Map = require "Map"
local ROOM_DB = 2
local user = {}

function user:init()
    event_handler:on("create_room",utils:handler(self,user.createRoom))
    event_handler:on("join_room",utils:handler(self,user.joinRoom))
    event_handler:on("sit_down",utils:handler(self,user.sitDown))
    event_handler:on("finish_deal",utils:handler(self,user.finishDeal))
    event_handler:on("leave_room",utils:handler(self,user.leaveRoom))
    event_handler:on("game_cmd",utils:handler(self,user.gameCmd))
    event_handler:on("distroy_room",utils:handler(self,user.distroyRoom))
    event_handler:on("confirm_distroy_room",utils:handler(self,user.confirmDistroyRoom))
    event_handler:on("get_my_room_list",utils:handler(self,user.getMyRoomList))

end

--获取房间列表的信息
function user:getMyRoomList(req_msg)
	local push_msg = {}
	push_msg.room_list = user_info:caculateRoomList()
    push_msg.room_id = user_info:get("room_id")
 	push_msg.result = "success"
 	return "get_my_room_list",push_msg
end

--创建房间
function user:createRoom(req_msg)
	local room_setting = req_msg.room_setting
	local round = room_setting.round
	if not round then
		return "create_room",{result = "paramater_error"}
	end

	local pay_type = room_setting.pay_type
	local cost
	--如果是房主出资 或者是赢家出资则判断资金是否足够
	if pay_type == constant["PAY_TYPE"]["ROOM_OWNER_COST"] or pay_type == constant["PAY_TYPE"]["WINNER_COST"] then
		cost = round * constant["ROUND_COST"] * -1
	elseif pay_type == constant["PAY_TYPE"]["AMORTIZED_COST"] then
		local seat_num = room_setting.seat_num
		cost = (math.floor(round * constant["ROUND_COST"])/seat_num) - 1
	end
	local enough = user_info:checkGoldNum(cost)
	if not enough then
		return "create_room",{result = "gold_not_enough"}
	end

	--room_id只有在玩家游戏的时候掉线并重新登录的时候存在
	--这时候需要判断该房间是否被解散掉,如果解散掉了则清掉room_id，并可以创建房间
	--否则无法创建房间
	local room_id = user_info:get("room_id")
	if room_id then
		local room_info = Map.new(ROOM_DB,"room:"..room_id)
		--如果房间已经被解散
		if not room_info.room_id then
			user_info:set("room_id",nil)
		else
			local is_sit = false
			local players = room_info.players
			for _,player in ipairs(players) do
				if player.user_id == user_info:get("user_id") then
					is_sit = player.is_sit
				end
			end
			print("is_sit=======>>",is_sit)
			if room_info.state == constant.ROOM_STATE.GAME_PREPARE and not is_sit then
				user_info:set("room_id",nil)
			elseif room_info.state == constant.ROOM_STATE.GAME_PREPARE and is_sit then
				return "create_room",{result = "current_in_room"}
			else
				return "create_room",{result = "current_in_game"}
			end
		end
	end

	local result,center_node = user_info:getCenterNode()
	if not result or not center_node then
		return "create_room",{result = "server_error"}
	end

	local info = user_info:getPropertys("user_id","user_name","user_pic","user_ip","gold_num")
	info.fd = user_info.fd
	info.node_name = skynet.getenv("node_name")
	local data = req_msg.room_setting
	for k,v in pairs(info) do
		data[k] = v
	end

	local success,result,room_id = user_info:safeClusterCall(center_node,".room_manager","createRoom",data)
	if not success then
		return "create_room",{result = "server_error"}
	end

	if result == "success" then
		user_info:set("room_id",room_id)
		local room_ids = user_info:get("room_ids")
		table.insert(room_ids,room_id)
		user_info:set("room_ids",room_ids)
	end

	return "create_room",{result = result}
end

--加入房间
function user:joinRoom(req_msg)
	local pre_room_id = user_info:get("room_id")
	if pre_room_id then
		local room_info = Map.new(ROOM_DB,"room:"..pre_room_id)
		--如果房间已经被解散
		if not room_info.room_id then
			user_info:set("room_id",nil)
		else
			local is_sit = false
			local players = room_info.players
			for _,player in ipairs(players) do
				if player.user_id == user_info:get("user_id") then
					is_sit = player.is_sit
				end
			end
			if room_info.state == constant.ROOM_STATE.GAME_PREPARE and not is_sit then
				user_info:set("room_id",nil)
			elseif room_info.state == constant.ROOM_STATE.GAME_PREPARE and is_sit then
				return "join_room",{result = "current_in_room"}
			else
				return "join_room",{result = "current_in_game"}
			end
		end
	end

	local room_id = req_msg.room_id
	local room_info = Map.new(ROOM_DB,"room:"..room_id)
	if not room_info.room_id then
		return "join_room",{result="not_exist_room"}
	end

	local round = room_info.round
	local pay_type = room_info.pay_type
	local seat_num = room_info.seat_num
	local cost = 0
	--如果是赢家出 或者是平摊 则判断资金是否足够
	if pay_type == constant["PAY_TYPE"]["WINNER_COST"] then
		cost = round * constant["ROUND_COST"] * -1
	elseif pay_type == constant["PAY_TYPE"]["AMORTIZED_COST"] then
		local seat_num = room_setting.seat_num
		cost = (math.floor(round * constant["ROUND_COST"])/seat_num) - 1
	end
	local enough = user_info:checkGoldNum(cost)
	if not enough then
		return "join_room",{result = "gold_not_enough"}
	end


	local center_node = room_info.node_name
	local data = user_info:getPropertys("user_id","user_name","user_pic","user_ip","gold_num")
	data.node_name = skynet.getenv("node_name")
	data.fd = user_info.fd

	for k,v in pairs(data) do
		req_msg[k] = v
	end

	local success,result = user_info:safeClusterCall(center_node,".room_manager","joinRoom",req_msg)
	if not success then
		return "join_room",{result="server_error"}
	end
 
	if result == "success" then
		user_info:set("room_id",room_id)
		local room_ids = user_info:get("room_ids")
		local has = nil
		for i,id in ipairs(room_ids) do
			if id == room_id then
				has = true
			end
		end
		if not has then
			table.insert(room_ids,room_id)
			user_info:set("room_ids",room_ids)
		end
	end

	return "join_room",{result=result}
end

--离开房间
function user:leaveRoom()
    local room_id = user_info:get("room_id")
    if not room_id then
        return "leave_room",{result = "succcess"}
    end
    local room_info = Map.new(ROOM_DB,"room:"..room_id)
	--如果房间已经被解散
	if not room_info.room_id then
		user_info:set("room_id",nil)
		return "leave_room",{result = "succcess"}
	end
    local center_node = room_info.node_name

    local user_id = user_info:get("user_id")
    local data = {room_id = room_id,user_id = user_id}
    local success,result = user_info:safeClusterCall(center_node,".room_manager","leaveRoom",data)

    if not success then
    	return "leave_room",{result="server_error"}
    end

    if result == "success" then
	    user_info:set("room_id",nil)
	end
	return "leave_room",{result = result}
end

--入座
function user:sitDown(req_msg)
	local room_id = user_info:get("room_id")
	if not room_id then  
		return "sit_down",{result = "not_in_room"}
	end

	local room_info = Map.new(ROOM_DB,"room:"..room_id)
	--如果房间已经被解散
	if not room_info.room_id then
		user_info:set("room_id",nil)
		return "sit_down",{result = "not_exist_room"}
	end
	local center_node = room_info.node_name
	local data = user_info:getPropertys("user_id")
	data.room_id = room_id
	data.pos = req_msg.pos

	local success,result = user_info:safeClusterCall(center_node,".room_manager","sitDown",data)
	if not success then
		return "sit_down",{result = "server_error"}
	end

	return "sit_down",{result = result}
end

--申请解散房间
function user:distroyRoom(req_msg)
	local room_id = req_msg.room_id
	if not room_id then  
		return "distroy_room",{result = "paramater_error"}
	end
	local room_info = Map.new(ROOM_DB,"room:"..room_id)
	--如果房间已经被解散
	if not room_info.room_id then
		user_info:set("room_id",nil)
		return "distroy_room",{result = "not_exist_room"}
	end
	local center_node = room_info.node_name
	req_msg.user_id = user_info:get("user_id")
	local success,result = user_info:safeClusterCall(center_node,".room_manager","distroyRoom",req_msg)
	if not success then
		return "distroy_room",{result = "server_error"}
	end

	return "distroy_room",{result=result}
end
--是否同意解散房间
function user:confirmDistroyRoom(req_msg)
	local room_id = user_info:get("room_id")
	if not room_id then  
		return "confirm_distory_room",{result = "not_in_room"}
	end
	local room_info = Map.new(ROOM_DB,"room:"..room_id)
	--如果房间已经被解散
	if not room_info.room_id then
		user_info:set("room_id",nil)
		return "confirm_distory_room",{result = "not_exist_room"}
	end
	local center_node = room_info.node_name
	req_msg.user_id = user_info:get("user_id")
	req_msg.room_id = room_id
	local success,result = user_info:safeClusterCall(center_node,".room_manager","confirmDistroyRoom",req_msg)
	if not success then
		return "confirm_distory_room",{result = "server_error"}
	end

	return "confirm_distory_room",{result=result}
end

--游戏命令 
function user:gameCmd(data)
	local room_id = user_info:get("room_id")
	if not room_id then  
		return "game_cmd",{result = "not_in_room"}
	end
	local room_info = Map.new(ROOM_DB,"room:"..room_id)
	--如果房间已经被解散
	if not room_info.room_id then
		user_info:set("room_id",nil)
		return "game_cmd",{result = "not_exist_room"}
	end
	local center_node = room_info.node_name
	data.user_id = user_info:get("user_id")
	data.room_id = room_id
	data.fd = user_info.fd
	local success,result = user_info:safeClusterCall(center_node,".room_manager","gameCMD",data)
	if not success then
		return "game_cmd",{result = "server_error"}
	end

	return "game_cmd",{result=result}
end


return user
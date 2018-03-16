local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local cluster = require "skynet.cluster"
local sharedata = require "skynet.sharedata"
local constant,config_manager,Room,RoomPool

local CMD = {}

--创建房间
function CMD.createRoom(data)
	local room = RoomPool:getUnusedRoom()
	room:setInfo(data)
	room:addPlayer(data)
	--筛选数据传递到客户端
	local filter1 = {"user_id","user_name","user_pic","user_ip","user_pos","is_sit"}
	local players = room:getPlayerInfo(table.unpack(filter1))
	local filter2 = {
						"room_id",
						"game_type",
						"round",
						"pay_type",
						"seat_num",
						"is_friend_room",
						"is_open_voice",
						"is_open_gps",
						"other_setting"
					}
	local rsp_msg = room:getPropertys(table.unpack(filter2))
	rsp_msg.players = players
	room:broadcastAllPlayers(constant.PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return constant.NET_RESULT.SUCCESS,room:get("room_id")
end

--加入房间
function CMD.joinRoom(data)

	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return constant.NET_RESULT.NOT_EXIST_ROOM,{}
	end

	room:addPlayer(data)

	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players

	room:broadcastAllPlayers(constant.PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)
 
	return constant.NET_RESULT.SUCCESS,rsp_msg
end

--离开房间
function CMD.leaveRoom(data)
	local room_id = data.room_id
	
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		log.warning("FYD=>leaveRoom has not room,room_id=",room_id)
		return constant.NET_RESULT.NOT_EXIST_ROOM
	end
	local user_id = data.user_id
	room:removePlayer(user_id)
	
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players

	room:broadcastAllPlayers(constant.PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return constant.NET_RESULT.SUCCESS
end

--坐下
function CMD.sitDown(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local pos = data.pos
	local room = RoomPool:getRoomByRoomID(room_id)
	if pos > room:get("seat_num") then
		return constant.NET_RESULT.INVALID_PARAMATER
	end
	local obj = room:getPlayerByPos(pos)
	--如果这个位置有人,并且处于坐下状态
	if obj and obj.is_sit then
		return constant.NET_RESULT.SIT_ALREADY_HAS
	end

	local player = room:getPlayerByUserId(user_id)
	player.is_sit = true

	room:updatePlayerProperty(user_id,"user_pos",pos)
	
	--推送
	local sit_list = room:getPlayerInfo("user_id","user_pos","is_sit")
	for i=#sit_list,1,-1 do
		local obj = sit_list[i]
		if not obj.is_sit then
			table.remove(sit_list,i)
		end
		obj.is_sit = nil
	end
	local rsp_msg = {room_id = room_id,sit_list = sit_list}
	room:broadcastAllPlayers(constant.PUSH_EVENT.PUSH_SIT_DOWN,rsp_msg)

	
	local full_seat = room:updatePlayerState(user_id,constant.PLAYER_STATE.SIT_DOWN_FINISH)
	if full_seat then
		--所有人都坐下之后 开始游戏
		skynet.call(room:get("service_id"),"lua","startGame",room:getAllInfo())
	end

	return constant.NET_RESULT.SUCCESS
end

--游戏指令
function CMD.gameCMD(data)

	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	local result = skynet.call(room:get("service_id"),"lua","gameCMD",data)
	return result
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        local args = {...}
        local cjson = require "cjson"
        print("\n")
        print("CMD = ",cmd)
        print(cjson.encode(args))
        print("\n")

        skynet.ret(skynet.pack(f(...)))
    end)
    math.randomseed(skynet.time())

    config_manager = require "config_manager"
    config_manager:init()
    constant = config_manager.constant

	Room = require "Room"
	RoomPool = require "RoomPool"

    -- --初始化房间池并预创建一部分房间
    RoomPool:init(config_manager.server_info)
    skynet.register ".room_manager"
end)

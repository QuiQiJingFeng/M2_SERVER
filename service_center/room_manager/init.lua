local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local cluster = require "skynet.cluster"
local Room = require "Room"
local constant = require "constant"
local NET_RESULT = constant.NET_RESULT
local PLAYER_STATE = constant["PLAYER_STATE"]
local PUSH_EVENT = constant["PUSH_EVENT"]
local ZJ_MODE = constant["ZJ_MODE"]

local CMD = {}

local RoomPool = require "RoomPool"

--创建房间
function CMD.createRoom(data)
	local room = RoomPool:getUnusedRoom()
	room:setInfo(data)

	room:addPlayer(data)
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players
	room:broadcastAllPlayers(PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return NET_RESULT.SUCCESS,room:get("room_id")
end

--加入房间
function CMD.joinRoom(data)
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return NET_RESULT.NOT_EXIST_ROOM,{}
	end

	room:addPlayer(data)

	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players

	room:broadcastAllPlayers(PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)
 
	return NET_RESULT.SUCCESS,rsp_msg
end

--离开房间
function CMD.leaveRoom(data)
	local room_id = data.room_id
	
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return NET_RESULT.NOT_EXIST_ROOM
	end
	local user_id = data.user_id
	room:removePlayer(user_id)
	
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players

	room:broadcastAllPlayers(PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return NET_RESULT.SUCCESS
end

--坐下
function CMD.sitDown(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local pos = data.pos
	local room = RoomPool:getRoomByRoomID(room_id)
	if pos > room:get("seat_num") then
		return NET_RESULT.FAIL
	end
	local player = room:getPlayerByPos(pos)
	if player then
		return NET_RESULT.SIT_ALREADY_HAS
	end

	if player.is_sit then
		return NET_RESULT.FAIL
	end

	room:updatePlayerProperty(user_id,"user_pos",pos)
	player.is_sit = true

	--推送
	local sit_list = room:getPlayerInfo("user_id","user_pos")
	for i=#sit_list,1,-1 do
		local obj = sit_list[i]
		if not obj.user_pos then
			table.remove(sit_list,i)
		end
	end
	local rsp_msg = {room_id = room_id,sit_list = sit_list}
	room:broadcastAllPlayers(PUSH_EVENT.PUSH_SIT_DOWN,rsp_msg)

	
	local full_seat = room:updatePlayerState(user_id,PLAYER_STATE.SIT_DOWN_FINISH)
	if full_seat then
		--所有人都坐下之后 开始游戏
		skynet.call(room:get("service_id"),"lua","startGame",room:getAllInfo())
	end

	return NET_RESULT.SUCCESS
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
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)

        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)
    math.randomseed(skynet.time())

    --初始化房间池并预创建一部分房间
    RoomPool:init()
    skynet.register ".room_manager"
end)

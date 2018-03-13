local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local cluster = require "skynet.cluster"

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
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip")
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

	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip")
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
	
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip")
	local rsp_msg = {room_id = room:get("room_id"),players = players}

	room:broadcastAllPlayers(PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return NET_RESULT.SUCCESS
end

--坐下
function CMD.sitDown(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local pos = data.pos
	local room = RoomPool:getRoomByRoomID(room_id)

	local player = room:getPlayerByPos(pos)
	if player and player.user_pos then
		return NET_RESULT.SIT_ALREADY_HAS
	end

	room:updatePlayerProperty(user_id,"user_pos",pos)
	local full_seat = room:updatePlayerState(user_id,PLAYER_STATE.SIT_DOWN_FINISH)

	--推送
	local sit_list = room:getPlayerInfo("user_id","user_pos")
	local rsp_msg = {room_id = room_id,sit_list = sit_list}
	room:broadcastAllPlayers(PUSH_EVENT.PUSH_SIT_DOWN,rsp_msg)

	if full_seat then
		--所有人都坐下之后 开始游戏
		-- skynet.call(room.service_id,"lua","startGame",room:getAllInfo())
	end

	return NET_RESULT.SUCCESS
end

--发牌完毕
function CMD.dealFinish(data)
	local room_id = data.room_id
	local user_id = data.user_id

	local room = RoomPool:getRoomByRoomID(room_id)
	local full = room:updatePlayerState(user_id,PLAYER_STATE.DEAL_FINISH)
	if full then
		--所有人都发牌完毕之后 开始游戏
		skynet.call(room.service_id,"lua","startGame",room:getAllInfo())
	end
end

--游戏指令
function CMD.gameCMD(data)
	local command = data.command
	local user_id = data.user_id
	local room = RoomPool:getRoomByUserID(user_id)
	local support = room:isSuportCommand(command)
	if not support then
		return "nosupport_command"
	end
	local result = skynet.call(room.service_id,"gameCMD",data)
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

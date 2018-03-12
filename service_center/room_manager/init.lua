local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local cluster = require "skynet.cluster"

local constant = require "constant"

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
	local rsp_msg = {room_id = room:get("room_id"),players = players}
	return "success",rsp_msg
end

--加入房间
function CMD.joinRoom(data)
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "not_exist_room",{}
	end
	
	room:addPlayer(data)

	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip")
	local rsp_msg = {room_id = room:get("room_id"),players = players}

	room:broadcastOtherPlayers(user_id,PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return "success",rsp_msg
end

--离开房间
function CMD.leaveRoom(data)
	local room_id = data.room_id
	local user_id = data.user_id

	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "success"
	end

	room:removePlayer(user_id)
	
	local rsp_msg = room:getPlayerInfo("user_id","user_name","user_pic","user_pos")
	room:broadcastOtherPlayers(user_id,PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return "success"
end

--准备
function CMD.prepare(data)
	local room_id = data.room_id
	local user_id = data.user_id

	local room = RoomPool:getRoomByRoomID(room_id)
	local full = room:updatePlayerState(user_id,PLAYER_STATE.PREPARE_FINISH)
	if full then
		--洗牌
		room:fisherYates()
		--发牌
		room:dealCards()
	end

	return "success"
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

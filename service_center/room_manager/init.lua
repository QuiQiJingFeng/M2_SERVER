local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local pbc = require "protobuf"
local redis = require "skynet.db.redis"
local cjson = require "cjson"
require "skynet.manager"
local cluster = require "skynet.cluster"

local mysql = require "skynet.db.mysql"
local md5 = require "md5"
local account_db

local STATE = {
	UN_PREPARE = 1,
	PREPARE = 2,
	GAME_STARTING = 3,
	GAME_END = 4
}

local CMD = {}

local room_pool = require "room_pool"

local function broadcast(players,msg_name,msg_data)
	for _,player in ipairs(players) do
		local source_node = player.source_node
		local service_adress = player.service_adress
		cluster.call(source_node, service_adress, "push",msg_name,msg_data)
	end
end

function CMD.battleProto(room_service_id,proto_name,proto_data)
	
end


function CMD.createRoom(user_id,user_name,source_node,service_adress)
	local room = room_pool:getUnusedRoom()
	local player = {user_id = user_id, user_name = user_name, source_node = source_node,service_adress = service_adress}
	player.state = STATE.UN_PREPARE
	room.players[1] = player

	return {room_id = room.room_id,players={[1] = {user_id = user_id,user_name = user_name}}}
end

function CMD.joinRoom(user_id,user_name,room_id,source_node,service_adress)
	local room = room_pool:getRoomByRoomID(room_id)
	local player = {user_id = user_id, user_name = user_name, source_node = source_node,service_adress = service_adress}
	table.insert(room.players,player)

	
	local other_players = {}
	local temp = {room_id = room_id,players={}}
	for _,player in ipairs(room.players) do
		local obj = { user_id = player.user_id, user_name = player.user_name}
		table.insert(temp.players,obj)
		if player.user_id ~= user_id then
			table.insert(other_players,player)
		end
	end

	--刷新其他玩家的房间信息
	broadcast(other_players,"refresh_room_info",temp)

	return temp
end

--离开房间
function CMD.leaveRoom(room_id,user_id)
	local room = room_pool:getRoomByRoomID(room_id)
	for index,player in ipairs(room.players) do
		if player.user_id == user_id then
			table.remove(room.players,index)
			break
		end
	end
	local players = {}
	for i,player in ipairs(room.players) do
		local obj = { user_id = player.user_id, user_name = player.user_name}
		table.insert(players,player)
	end

	--刷新其他玩家的房间信息
	broadcast(room.players,"refresh_room_info",temp)
end

--准备
function CMD.prepare(room_id,user_id)
	local room = room_pool:getRoomByRoomID(room_id)
	for k,player in pairs(room.players) do
		if palyer.user_id == user_id then
			palyer.state = STATE.PREPARE
			break
		end
	end
end

--开始游戏
function CMD.startGame()
	local room = room_pool:getRoomByRoomID(room_id)
	local num = 0
	for k,player in pairs(room.players) do
		if palyer.state == STATE.PREPARE then
			num = num + 1
		end
	end
end

--获取房间的信息
function CMD.GetRoomInfo(room_id)
	return room_pool:getRoomByRoomID(room_id)
end

function CMD.DistroyRoom(room_id)
	room_pool:cleanRoom(room_id)
end

function CMD.JoinRoom(room_id,user_id)
	local room = room_pool:getRoomByRoomID(room_id)
	table.insert(room.players,user_id)


	return room
end

function CMD.StartGame(user_id)
	local room = room_pool:getRoomByUserID(user_id)
	if not room then
		return false,"not_room"
	end
	room.state = "game_fight"
	skynet.call(room.service_id,"lua","StartGame",room)
end

--游戏指令
function CMD.GameCMD(user_id,source_node_name,info)
	local room = room_pool:getRoomByUserID(user_id)
	return skynet.call(room.service_id,GameCMD,user_id,command,info)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    room_pool:init()
    skynet.register ".room_manager"
end)

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

--广播消息
local function broadcast(players,msg_name,msg_data)
	for _,player in ipairs(players) do
		local node_name = player.node_name
		local service_id = player.service_id
		cluster.call(node_name, service_id, "push",msg_name,msg_data)
	end
end

local function createRoomTemp(room)
	local temp = {}
	temp.room_id = room.room_id
	temp.players = {}
	for i,player in ipairs(room.players) do
		local tp = {}
		tp.user_id = player.user_id
		tp.user_name = player.user_name
		table.insert(temp.players,tp)
	end
	return temp
end

--创建房间
--参数:node_name 为用户所在的游戏服务器结点的名称
--参数:service 为用户在该游戏结点上服务的名称
function CMD.createRoom(user_id,user_name,node_name,service_id)
	--获取一个没有使用到的房间
	local room = room_pool:getUnusedRoom()
	--构建玩家数据
	local player = { user_id = user_id, user_name = user_name, node_name = node_name,service_id = service_id}
	--将玩家数据添加入房间信息中
	table.insert(room.players,player)
	--设定玩家的状态为 未准备 状态
	player.state = STATE.UN_PREPARE

	local temp = createRoomTemp(room)

	return "success",temp
end

--加入房间
function CMD.joinRoom(room_id,user_id,user_name,node_name,service_id)
	--通过房间号来获取对应的房间信息
	local room = room_pool:getRoomByRoomID(room_id)
	--构建玩家数据
	local player = {user_id = user_id, user_name = user_name, node_name = node_name,service_id = service_id}
	--将玩家数据添加入房间信息中
	table.insert(room.players,player)
	--设定玩家的状态为 未准备 状态
	player.state = STATE.UN_PREPARE

	--通知除了该玩家之外的其他玩家,有人加入房间
	local other_players = {}
	for _,player in ipairs(room.players) do
		if player.user_id ~= user_id then
			table.insert(other_players,player)
		end
	end

	local temp = createRoomTemp(room)
	--刷新其他玩家的房间信息
	broadcast(other_players,"refresh_room_info",temp)



	return "success",temp
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
	local temp = createRoomTemp(room)
	--刷新剩余玩家的房间信息
	broadcast(room.players,"refresh_room_info",temp)

	return "success"
end

--准备
function CMD.prepare(room_id,user_id)
	local room = room_pool:getRoomByRoomID(room_id)
	for k,player in pairs(room.players) do
		if palyer.user_id == user_id then
			--如果当前没有处于准备状态
			if palyer.state ~= STATE.PREPARE then
				palyer.state = STATE.PREPARE
				room.prepare_num = room.prepare_num + 1
			else
				return "repeate_prepare"
			end
			break
		end
	end
	return "success"
end

--开始游戏
function CMD.startGame(game_type,player_num)
	local room = room_pool:getRoomByRoomID(room_id)
	if need_num ~= room.prepare_num then
		return "node_enough_prepare"
	end

	skynet.call(room.service_id,"lua","startGame",game_type,room)

	return "success"
end

--获取房间的信息
function CMD.getRoomInfo(room_id)
	return "success",room_pool:getRoomByRoomID(room_id)
end

--游戏指令
function CMD.gameCMD(command,user_id,info)
	local room = room_pool:getRoomByUserID(user_id)
	skynet.call(room.service_id,"gameCMD",command,user_id,info)
	return "success"
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)
    --初始化房间池并预创建一部分房间
    room_pool:init()
    skynet.register ".room_manager"
end)

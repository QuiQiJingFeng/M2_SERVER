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

--玩家断开连接 游戏服根据返回结果决定是否清掉玩家身上绑定的房间ID
--如果玩家在游戏没有开始的时候掉线,则离开房间
function CMD.userDisconnect(data)
    local room_id = data.room_id
    local user_id = data.user_id

	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return true
	end

	local player = room:getPlayerByUserId(user_id)
	if not player then
		return true
	end
	player.isconnect = false

	local state = room:get("state")
	if state == constant.ROOM_STATE.GAME_PLAYING then
		--此时不会清掉玩家绑定的房间号
		log.warningf("玩家[%s]掉线,但是房间[%d]在游戏当中",user_id,room_id)
		skynet.call(room:get("service_id"),"lua","userDisconnect",data)
		--如果在游戏中 还需要通知其他玩家 有玩家掉线
		room:broadcastAllPlayers(constant.PUSH_EVENT.NOTICE_PLAYERS_DISCONNECT,{user_id=user_id})
		return false
	end

	CMD.leaveRoom(data)

	return true
end

--离开房间
function CMD.leaveRoom(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		log.warningf("玩家[%s]离开房间[%d],但是没有找到房间号",user_id,room_id)
		return constant.NET_RESULT.NOT_EXIST_ROOM
	end
	local state = room:get("state")
	if state == constant.ROOM_STATE.GAME_PLAYING then
		log.warningf("当前正在游戏中,玩家[%s]无法离开房间[%d]",user_id,room_id)
		return constant.NET_RESULT.FAIL
	end

	room:removePlayer(user_id)
	
	local players = room:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit")
	local rsp_msg = room:getPropertys("room_id","game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.players = players

	room:broadcastAllPlayers(constant.PUSH_EVENT.REFRESH_ROOM_INFO,rsp_msg)

	return constant.NET_RESULT.SUCCESS
end

--是否可以返回房间
function CMD.canBackRoom(data)

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

	local round = room:get("round")
	if round <= 0 then
		return NET_RESULT.ROUND_NOT_ENOUGH
	end
	local player = room:getPlayerByUserId(user_id)
	local obj = room:getPlayerByPos(pos)
	--如果该位置有人(不是自己的话）则不能入座
	if obj and obj.user_id ~= player.user_id then
		return constant.NET_RESULT.SIT_ALREADY_HAS
	end
	--如果已经是准备状态了
	if player.is_sit then
		return constant.NET_RESULT.SUCCESS
	end

	
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

	local sit_down_num = self:get("sit_down_num")
	sit_down_num = sit_down_num + 1
	self:set("sit_down_num",sit_down_num)
	local seat_num = room:get("seat_num")
	if seat_num == sit_down_num then
		local origin_round = room:get("origin_round")
		local round = room:get("round")
		if origin_round = round then
			--第一回合开始后,重新设定房间的释放时间
			local now = skynet.time()
			room:set("expire_time",now + 12*60*60)
		end
		--所有人都坐下之后 开始游戏
		room:set("state",constant.ROOM_STATE.GAME_PLAYING)
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

--游戏结束 更新房间的状态
function CMD.gameOver(room_id)
	local room = RoomPool:getRoomByRoomID(room_id)
	--更新游戏的局数
	local round = room:get("round")
	local origin_round = room:get("origin_round")
	--如果第一局结束 结算金币
	if origin_round == round then
		--TODO
	end

	room:set("round",round - 1)
	room:set("state",constant.ROOM_STATE.GAME_OVER)
	local players = room:get("players")
	for i,player in ipairs(players) do
		player.is_sit = nil
	end
	self:set("sit_down_num",0)


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

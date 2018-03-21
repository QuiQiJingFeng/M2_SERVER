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
	room:refreshRoomInfo()

	return "success",room:get("room_id")
end

--加入房间
function CMD.joinRoom(data)

	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "not_exist_room"
	end

	room:addPlayer(data)

	room:refreshRoomInfo()
 
	return constant.NET_RESULT.SUCCESS
end

--离开房间
function CMD.leaveRoom(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "not_exist_room"
	end
	local state = room:get("state")
	if state ~= constant.ROOM_STATE.GAME_PREPARE then
		return "current_in_game"
	end

	room:removePlayer(user_id)
	room:refreshRoomInfo()

	return "success"
end

function CMD.goBackRoom(data)
	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "not_exist_room",{}
	end

	local data = skynet.call(room:get("service_id"),"lua","goBackRoom",data)
end

--坐下
function CMD.sitDown(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local pos = data.pos
	local room = RoomPool:getRoomByRoomID(room_id)
	if pos > room:get("seat_num") then
		return "paramater_error"
	end

	local round = room:get("round")
	if round <= 0 then
		return "round_not_enough"
	end
	local player = room:getPlayerByUserId(user_id)
	local obj = room:getPlayerByPos(pos)
	--如果该位置有人(不是自己的话）则不能入座
	if obj and obj.user_id ~= player.user_id then
		return "pos_has_player"
	end

	--如果已经是准备状态了
	if player.is_sit then
		return "already_sit"
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
	room:broadcastAllPlayers("push_sit_down",rsp_msg)

	local sit_down_num = room:get("sit_down_num")
	sit_down_num = sit_down_num + 1
	room:set("sit_down_num",sit_down_num)
	local seat_num = room:get("seat_num")
	if seat_num == sit_down_num then
		local cur_round = room:get("cur_round")
		--开始游戏之后局数+1
		room:set("cur_round",cur_round+1)
		--所有人都坐下之后 开始游戏
		room:set("state",constant.ROOM_STATE.GAME_PLAYING)

		if cur_round == 1 then
			--第一回合开始后,重新设定房间的释放时间
			local now = skynet.time()
			room:set("expire_time",now + 12*60*60)
			--推送到客户端,本房间的状态发生改变
			room:broadcastAllPlayers("update_room_state",{room_id=room:get("room_id"),state = room:get("state")})
		end
		
		skynet.call(room:get("service_id"),"lua","startGame",room:getAllInfo())
	end

	return "success"
end

--FYD
--游戏指令
function CMD.gameCMD(data)
	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	local result = skynet.call(room:get("service_id"),"lua","gameCMD",data)

	local command = data.command
	if command == "BACK_ROOM" and result == "success" then
		local fd = data.fd
		local room = RoomPool:getRoomByRoomID(room_id)
		--如果是返回房间,需要更新fd
		room:set("fd",fd)
	end
	return result
end

--游戏结束 更新房间的状态
function CMD.gameOver(room_id)
	local room = RoomPool:getRoomByRoomID(room_id)
	local cur_round = room:get("cur_round")
	local round = room:get("round")
	if cur_round == 1 then
		local cost = round * constant["ROUND_COST"]
		local pay_type = self.room:get("pay_type")
		if pay_type == constant.PAY_TYPE.ROOM_OWNER_COST then
			--房主出资
			local owner_id = self.room:get("owner_id")
			local player = self.room:getPlayerByUserId(owner_id)
			--更新玩家的金币数量
			local gold_num = cluster.call(player.node_name,".agent_manager","updateResource",owner_id,"gold_num",-1*cost)
			player.gold_num = gold_num
			room:refreshRoomInfo()
		elseif pay_type == constant.PAY_TYPE.AMORTIZED_COST then
			--平摊
			local seat_num = self.room:get("seat_num")
			local per_cost = math.floor(cost / seat_num)
			local players = self.room:get("players")
			for i,obj in ipairs(players) do
				local gold_num = cluster.call(obj.node_name,".agent_manager","updateResource",obj.user_id,"gold_num",-1*per_cost)
				obj.gold_num = gold_num
			end
			room:refreshRoomInfo()
		end   
	end

	room:set("state",constant.ROOM_STATE.GAME_OVER)
	local players = room:get("players")
	for i,player in ipairs(players) do
		player.is_sit = nil
	end
	self:set("sit_down_num",0)
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

	local state = room:get("state")
	if state == constant.ROOM_STATE.GAME_PLAYING then
		--此时不会清掉玩家绑定的房间号
		log.warningf("玩家[%s]掉线,但是房间[%d]在游戏当中",user_id,room_id)
		--如果在游戏中 还需要通知其他玩家 有玩家掉线
		room:broadcastAllPlayers(constant.PUSH_EVENT.NOTICE_PLAYERS_DISCONNECT,{user_id=user_id})
		return false
	end

	room:removePlayer(user_id)
	
	room:refreshRoomInfo()

	return true
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

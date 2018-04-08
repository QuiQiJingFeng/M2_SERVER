local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local cluster = require "skynet.cluster"
local sharedata = require "skynet.sharedata"
local cjson = require "cjson"
local constant,config_manager,Room,RoomPool

local CMD = {}

--创建房间
function CMD.createRoom(data)
	local room = RoomPool:getUnusedRoom()
	room:setInfo(data)
	room:addPlayer(data)
	--筛选数据传递到客户端
	room:refreshRoomInfo()

	local room_id = room:get("room_id")
	local args = {user_id = data.user_id,room_id = room_id,time="NOW()"}
	skynet.send(".mysql_pool","lua","insertTable","create_room",args)

	return "success",room_id
end

--加入房间
function CMD.joinRoom(data)

	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return "not_exist_room"
	end

	local seat_num = room:get("seat_num")
	local player_num = #room:get("players")
	if player_num >= seat_num then
		return "no_position"
	end
	room:addPlayer(data)

	room:refreshRoomInfo()

	local room_id = room:get("room_id")
	local args = {user_id = data.user_id,room_id = room_id,time="NOW()"}
	skynet.send(".mysql_pool","lua","insertTable","join_room",args)
 
	return constant.NET_RESULT.SUCCESS
end
--断开连接的话,检测是否已经坐下,如果已经坐下则不处理,否则踢出房间
function CMD.disconnect(data)
	local room_id = data.room_id
	local user_id = data.user_id
	local room = RoomPool:getRoomByRoomID(room_id)
	if not room then
		return
	end
	local player = room:getPlayerByUserId(user_id)
	if player and player.is_sit then
		return 
	end

	CMD.leaveRoom(data)
end

--离开房间 客户端只在游戏开始无法离开房间
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

	local room_id = room:get("room_id")
	local args = {user_id = data.user_id,room_id = room_id,time="NOW()"}
	skynet.send(".mysql_pool","lua","insertTable","leave_room",args)

	return "success"
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
	room:set("players",room:get("players"))
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
		end



		local replay_id = skynet.call(".redis_center","lua","INCRBY",1,"replay_id_generator", 1)
		room:set("replay_id",replay_id)

		local msg = cjson.encode(room.property:getValues())
		skynet.send(".replay_cord","lua","insertRecord",replay_id,msg)

		local game_type = room:get("game_type")
		skynet.send(room:get("service_id"),"lua","startGame",room_id,game_type)
	end

	return "success"
end

--申请解散房间  
function CMD.distroyRoom(data)
	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	local owner_id = room:get("owner_id")
	local type = data.type
	--如果是房主解散房间
	if type == constant.DISTORY_TYPE.OWNER_DISTROY then
		if room:get("state") ~= constant.ROOM_STATE.GAME_PREPARE or user_id ~= owner_id then
			return "no_permission_distroy"
		else
			RoomPool:distroyRoom(room_id,constant.DISTORY_TYPE.OWNER_DISTROY)
			return "success"
		end
	end
	--如果是申请解散房间
	if type ==  constant.DISTORY_TYPE.ALL_AGREE then
		room:set("can_distory",true)
		local players = room:get("players")
		local confirm_map = room:get("confirm_map")
		for i,obj in ipairs(players) do
			confirm_map[obj.user_id] = false
		end
		confirm_map[user_id] = true

		room:set("confirm_map",confirm_map)
		
		for i,player in ipairs(players) do
			if user_id ~= player.user_id then --通知其他人有人申请解散房间
				room:sendMsgToPlyaer(player,"notice_other_distroy_room",{})
			end
		end

		--2分钟 如果玩家仍然没有同意,则自动同意
		skynet.timeout(constant["AUTO_CONFIRM"],function() 
				local room = RoomPool:getRoomByRoomID(room_id)
				if not room then
					print("这个房间已经被解散了")
					--如果这个房间已经被解散了
					return 
				end
				local can_distory = room:get("can_distory")
				if not can_distory then
					print("这个房间已经被人拒绝解散了")
					--如果这个房间已经被人拒绝解散了
					return 
				end
				--遍历所有没有同意的玩家,让他同意
				local confirm_map = room:get("confirm_map")
				for user_id,confirm in pairs(confirm_map) do
					if not confirm then
						CMD.confirmDistroyRoom({user_id=user_id,room_id=room_id,confirm=true})
					end
				end
			end)
		return "success"
	end
	return "paramater_error"
end

function CMD.confirmDistroyRoom(data)
	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	local confirm = data.confirm
	local can_distory = room:get("can_distory")
	if not can_distory then
		--非法的请求
		return "no_support_command"
	end
	local players = room:get("players")
	if confirm then
		local confirm_map = room:get("confirm_map")
		confirm_map[user_id] = true
		room:set("confirm_map",confirm_map)
		--当前玩家的数量
		local player_num = 0
		for i,player in ipairs(players) do
			if not player.disconnect then
				player_num = player_num + 1
			end
		end
		local num = 0
		for k,v in pairs(confirm_map) do
			num = num + 1
		end

		--如果所有人都点了确定
		if num == player_num then
			room:set("can_distory",false)
			RoomPool:distroyRoom(room_id,constant.DISTORY_TYPE.ALL_AGREE)
		end
	else
		local s_player = room:getPlayerByUserId(user_id)

		--如果有人不同意,则通知其他人 谁不同意
		local players = room:get("players")
		for i,player in ipairs(players) do
			if user_id ~= player.user_id then
				room:sendMsgToPlyaer(player,"notice_other_refuse",{user_id=s_player.user_id,user_pos=s_player.user_pos})
			end
		end
		room:set("confirm_map",{})
		room:set("can_distory",false)
	end

	return "success"
end

--FYD
--游戏指令
function CMD.gameCMD(data)
	local user_id = data.user_id
	local room_id = data.room_id
	local room = RoomPool:getRoomByRoomID(room_id)
	local command = data.command
	if command == "BACK_ROOM" then
		--返回房间
		local fd = data.fd
		local player = room:getPlayerByUserId(user_id)
		if not player then
			return "not_in_room"
		end
		local room = RoomPool:getRoomByRoomID(room_id)
		--如果是返回房间,需要更新fd
		player.fd = fd
	end

	local result
	--如果游戏还在未准备状态
	if command == "BACK_ROOM" and room:get("state") == constant.ROOM_STATE.GAME_PREPARE then
		room:refreshRoomInfo()
		return "success"
	end

	local result = skynet.call(room:get("service_id"),"lua","gameCMD",data)

	return result
end

--游戏结束 某局结束
function CMD.gameOver(room_id,room_info)
	local room = RoomPool:getRoomByRoomID(room_id)
	local replay_id = room:get("replay_id")

	room.rebuild(room_info)

	local cur_round = room:get("cur_round")
	local round = room:get("round")
	if cur_round == 1 then
		--用一个字段标记第一局是否完毕,用来在房间解散的时候结算大赢家的金币
		room:set("is_first_over",true)
	end
	if cur_round == round then
		RoomPool:distroyRoom(room_id)
	end

	skynet.send(".replay_cord","lua","saveRecord",replay_id)
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
        if not f then
        	log.error("ERROR: not command")
        	return
        end

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

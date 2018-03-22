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
	local command = data.command
	if command == "DISTROY_ROOM" then
		local players = room:get("players")
		if data.alloc then
			room:set("can_distory",true)
			local confirm_map = room:get("confirm_map")
			confirm_map[user_id] = true
			room:set("confirm_map",confirm_map)
			for i,player in ipairs(players) do
				if user_id ~= player.user_id then --通知其他人有人申请解散房间
					room:sendMsgToPlyaer(player,"notice_other_distroy_room",{})
				end
			end
			return "success"
		end
		local can_distory = room:get("can_distory")
		if not can_distory then
			return "success"
		end
		if data.confirm then
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
				num = num + 1 --TODO
			end

			--如果所有人都点了确定
			if num == player_num then
				local cur_round = room:get("cur_round")
				--如果回合数大于1 则发送结算界面
				if cur_round >= 1 then
					skynet.call(room:get("service_id"),"lua","gameCMD",data)
				end
				room:set("can_distory",false)
				RoomPool:distroyRoom(room_id)
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

	if command == "BACK_ROOM" then
		local fd = data.fd
		local player = room:getPlayerByUserId(user_id)
		--重新返回房间将标记重置
		player.disconnect = false
		room:set("players",room:get("players"))
		local room = RoomPool:getRoomByRoomID(room_id)
		--如果是返回房间,需要更新fd
		room:set("fd",fd)

		data.gold_list = room:getPlayerInfo("user_id","gold_num")
	end
	local result = skynet.call(room:get("service_id"),"lua","gameCMD",data)

	return result
end

--游戏结束 更新房间的状态
function CMD.gameOver(room_id)
	local room = RoomPool:getRoomByRoomID(room_id)
	local cur_round = room:get("cur_round")
	local round = room:get("round")
	if cur_round == 1 then
		local cost = round * constant["ROUND_COST"]
		local pay_type = room:get("pay_type")
		if pay_type == constant.PAY_TYPE.ROOM_OWNER_COST then
			--房主出资
			local owner_id = room:get("owner_id")
			local player = room:getPlayerByUserId(owner_id)
			--更新玩家的金币数量
			local gold_num = cluster.call(player.node_name,".agent_manager","updateResource",owner_id,"gold_num",-1*cost)
			player.gold_num = gold_num

			local gold_list = {{user_id = owner_id,user_pos = player.user_pos,gold_num=gold_num}}
			room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
			
		elseif pay_type == constant.PAY_TYPE.AMORTIZED_COST then
			--平摊
			local seat_num = room:get("seat_num")
			local per_cost = math.floor(cost / seat_num)
			local players = room:get("players")
			local gold_list = {}
			for i,obj in ipairs(players) do
				local info = {user_id = obj.user_id,user_pos=obj.user_pos}
				local gold_num = cluster.call(obj.node_name,".agent_manager","updateResource",obj.user_id,"gold_num",-1*per_cost)
				obj.gold_num = gold_num
				info.gold_num = gold_num
				table.insert(gold_list,info)
			end
			room:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end   
	end

	room:set("state",constant.ROOM_STATE.GAME_OVER)
	local players = room:get("players")
	for i,player in ipairs(players) do
		player.is_sit = nil
	end
	room:set("sit_down_num",0)
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
	player.disconnect = true
	room:set("players",room:get("players"))
	room:noticePlayerDisconnect(player)

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

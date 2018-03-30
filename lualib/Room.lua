local skynet = require "skynet"
local cluster = require "skynet.cluster"
local constant = require "constant"
local log = require "skynet.log"
local cjson = require "cjson"
local Map = require "Map"

local ZJ_MODE = constant["ZJ_MODE"]
local ALL_GAME_NUMS = constant["ALL_GAME_NUMS"]
local ALL_ZJ_MODE = constant["ALL_ZJ_MODE"]
local ALL_CARDS = constant["ALL_CARDS"]
local ALL_DEAL_NUM = constant["ALL_DEAL_NUM"]
local ALL_COMMAND = constant["ALL_COMMAND"]
local OPERATER = constant["OPERATER"]
local PUSH_EVENT = constant["PUSH_EVENT"]
local ROOM_STATE = constant.ROOM_STATE
local RECOVER_GAME_TYPE = constant["RECOVER_GAME_TYPE"]
local PAY_TYPE = constant.PAY_TYPE
local REDIS_DB = 2
local Room = {}

Room.__index = Room

function Room.new(room_id,node_name,service_id)
	local room_key = "room:"..room_id
	local new_room = { property = Map.new(REDIS_DB,room_key)}
	setmetatable(new_room, Room)
	new_room.__index = Room
	new_room:init(room_id,node_name,service_id)

	return new_room
end

--使用数据重建房间,因为虚拟机之间只能传递数据,所以需要重新构建
function Room.rebuild(property)
	local room_id = property.room_id
	local room_key = "room:"..room_id
	local new_room = { property = Map.new(REDIS_DB,room_key)}
	new_room.property:updateValues(property)
	setmetatable(new_room, Room)
	new_room.__index = Room
	return new_room
end

--从数据库恢复房间
function Room.recover(room_key)
	local new_room = { property = Map.new(REDIS_DB,room_key)}
	setmetatable(new_room, Room)
	new_room.__index = Room

	return new_room
end


--重用房间
function Room:reuse(room_id)
	local node_name = self.property.node_name
	local service_id = self.property.service_id
	local room_key = "room:"..room_id
	self.property = Map.new(REDIS_DB,room_key)
	self:init(room_id,node_name,service_id)
end

function Room:init(room_id,node_name,service_id)
	local info = {}
	info.room_id = room_id                      --房间ID
	info.node_name = node_name					--房间所在的服务器地址
	info.service_id = service_id 				--房间服务地址
	info.players = {}							--房间中的玩家列表
	info.sit_down_num = 0						--坐下的人数
	info.state = ROOM_STATE.GAME_PREPARE		--房间的状态
	info.expire_time = skynet.time() + 30*60	--房间的解散时间
	info.confirm_map = {}                       --同意解散房间的人员字典
	info.can_distory = false					--是否可以销毁房间
	info.card_list = {}                         --房间的牌池
	info.cur_play_user = nil                    --当前的出牌人
	info.cur_play_card = nil                    --当前出的牌
	info.is_first_over = false
	info.replay_id = nil                        --当前战局ID
	self.property:updateValues(info)
end

function Room:setInfo(info)
	local data = {}
	data.owner_id = info.user_id                --房间创建人
	data.game_type = info.game_type             --游戏类型
	data.round = info.round                     --房间回合数
	data.pay_type = info.pay_type				--资费类型
	data.seat_num = info.seat_num               --座位的数量
	data.is_friend_room = info.is_friend_room   --是否是好友房
	data.is_open_voice = info.is_open_voice     --是否开启声音
	data.is_open_gps = info.is_open_gps         --是否开启GPS
	data.other_setting = info.other_setting     --其他设置
	data.cur_round = 0          				--当前回合数
	self.property:updateValues(data)
end

--获取房间的属性
function Room:get(property_name)
	return self.property[property_name]
end

--设置房间的属性
function Room:set(property_name,value)
	self.property[property_name] = value
end

--添加玩家
function Room:addPlayer(info)
	local player = {}
	player.user_id = info.user_id                --玩家的ID
	player.user_name = info.user_name            --玩家的名称
	player.user_pic = info.user_pic              --玩家头像的url
	player.user_ip = info.user_ip                --玩家IP
	player.node_name = info.node_name            --玩家所在游戏服的地址
	player.score = 0                             --积分
	player.cur_score = 0                         --当前局的积分
	player.fd = info.fd                          --玩家的fd
	player.gold_num = info.gold_num				 --玩家的金币数量
	player.disconnect = false                    --玩家是否掉线

	--记录下玩家重开始到房间结束 总的 杠、胡、奖码 的个数
	player.hu_num = 0
	player.ming_gang_num = 0
	player.an_gang_num = 0
	player.reward_num = 0


	--记录已经碰或者杠的牌 记录下碰谁的牌
	--item = {card=card,from=user_id,type=type,gang_type=gang_type}
	player.card_stack = {}
	player.handle_cards = {}
	table.insert(self.property.players,player)

	local already_pos = {}
	for _,obj in ipairs(self.property.players) do
		if obj.user_pos then
			already_pos[obj.user_pos] = true
		end
	end
	local unused_pos = nil
	for pos=1,self:get("seat_num") do
		if not already_pos[pos] then
			unused_pos = pos
			break
		end
	end

	player.user_pos = unused_pos
	player.is_sit = false

	self:set("players",self.property.players)
end

--删除玩家
function Room:removePlayer(user_id)
	for index,player in ipairs(self.property.players) do
		if player.user_id == user_id then
			table.remove(self.property.players,index)
			local sit_down_num = self:get("sit_down_num")
			self:set("sit_down_num",sit_down_num-1)
			self:set("players",self.property.players)
			break
		end
	end
end


function Room:getPlayerByPos(pos)
	for _,player in ipairs(self.property.players) do
		if pos == player.user_pos then
			return player
		end
	end
end

function Room:getPlayerByUserId(user_id)
	for _,player in ipairs(self.property.players) do
		if user_id == player.user_id then
			return player
		end
	end
end



function Room:getPropertys(...)
	local args = {...}
	local info = {}
	for i,v in ipairs(args) do
		info[v] = self.property[v]
	end
	return info
end

--获取所有玩家的信息
function Room:getPlayerInfo(...)
	local filters = {...}
	local info = {}
	for _,player in ipairs(self.property.players) do
		local temp = {}
		for _,key in ipairs(filters) do
			temp[key] = player[key]
		end
		table.insert(info,temp)
	end
	return info
end

function Room:getAllInfo()
	return self.property:getValues()
end

--更新玩家的属性
function Room:updatePlayerProperty(user_id,name,value)
	for index,player in ipairs(self.property.players) do
		if player.user_id == user_id then
			player[name] = value
			return true
		end
	end
	return false
end

--FYD
function Room:refreshRoomInfo()
	local rsp_msg = {}
	local players = self:getPlayerInfo("user_id","user_name","user_pic","user_ip","user_pos","is_sit","gold_num","score","cur_score")
	local room_setting = self:getPropertys("game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting","cur_round")
	rsp_msg.room_setting = room_setting
	rsp_msg.room_id = self:get("room_id")
	rsp_msg.state = self:get("state")
	rsp_msg.players = players

	self:broadcastAllPlayers("refresh_room_info",rsp_msg)
end

--像游戏服推送消息
function Room:pushEvent(node_name,player,msg_name,msg_data)
	local replay_id = self:get("replay_id")
	if replay_id then
		skynet.send(".replay_cord","lua","insertRecord",replay_id,cjson.encode({[msg_name]=msg_data}))
	end
	local fd = player.fd
	local user_id = player.user_id
	if player.disconnect then
		return
	end
	local success,result = pcall(cluster.call,node_name, ".agent_manager", "pushEvent",fd, msg_name, msg_data)
	if not success then
		log.infof("向游戏服[%s]推送消息[%s]失败\n内容如下:\n%s",cjson.encode(msg_data))
	end

	if result == "NOT_ONLINE" then
		--如果之前是连接状态,则标记为断开状态并且通知其他人有人断开
		if not player.disconnect then
			player.disconnect = true
			self:noticePlayerConnectState(player,false)
			log.infof("玩家[%s]断开连接",user_id)
		end
	else
		--如果之前是断开状态,则标记为连接状态,并且通知其他人,该玩家已经连上
		if player.disconnect then
			player.disconnect = false
			self:noticePlayerConnectState(player,true)
			log.infof("玩家[%s]重新连接成功",user_id)
		end
	end
end

--广播消息
function Room:broadcastAllPlayers(msg_name,msg_data)
	for _,player in ipairs(self.property.players) do
		local node_name = player.node_name
		self:pushEvent(node_name,player,msg_name,msg_data)
	end
end

--向某个人发送消息
function Room:sendMsgToPlyaer(player,msg_name,msg_data)
	local node_name = player.node_name
	self:pushEvent(node_name,player,msg_name,msg_data)
end

--通知有玩家掉线
function Room:noticePlayerConnectState(player,is_connect)
	self:broadcastAllPlayers("notice_player_connect_state",{user_id=player.user_id,user_pos=player.user_pos,is_connect=is_connect})
end

--清理房间
function Room:distroy()
	local room_id = self:get("room_id")
	local service_id = self:get("service_id")
	local node_name = self:get("node_name")

	local cur_round = self:get("cur_round")
	local round = self:get("round")
	--赢家出资,如果在房间要释放掉的时候仍然没有结算,则积分高的掏钱
	local cost = round * constant["ROUND_COST"]
	local pay_type = self:get("pay_type")
	--检查大赢家的金币结算,如果打完第一局之后解散则需要掏钱
	local is_first_over = self:get("is_first_over")
	if cur_round >= 1 and is_first_over then
		--赢家出资 积分高的掏钱
		if pay_type == PAY_TYPE.WINNER_COST then
			table.sort(players,function(a,b) 
					return a.score > b.score
				end)
			local player = players[1]
			local max_score = player.score
			--大赢家列表
			local winners = {}
			for i,obj in ipairs(players) do
				if obj.score == max_score then
					table.insert(winners,obj)
				end
			end
			local gold_list = { }
			local per_cost = math.floor(cost/#winners)
			for _,obj in ipairs(winners) do
				local gold_num = self:safeClusterCall(obj.node_name,".agent_manager","updateResource",obj.user_id,"gold_num",-1*per_cost)
				obj.gold_num = gold_num
				local info = {user_id=obj.user_id,user_pos=obj.user_pos,gold_num=gold_num}
				table.insert(gold_list,info)
			end
			self:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
		end
	end

	if cur_round >= 1 and is_first_over then
		skynet.call(service_id,"lua","gameCMD",{command="DISTROY_ROOM"})
	end

	local room_key = "room:"..room_id
	--删除掉房间信息
	skynet.call(".redis_center","lua","DEL",REDIS_DB,room_key)

	--清理房间服务的数据
	skynet.call(service_id,"lua","clear")
	--还原初始的属性
	self.property = {service_id=service_id,node_name=node_name}
	log.infof("房间%d被销毁",room_id)
end

return Room
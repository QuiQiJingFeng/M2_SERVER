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
	info.can_distory = false
	info.waite_operators = {}                   --等待玩家操作的列表
	info.card_list = {}                         --房间的牌池
	info.cur_play_user = nil                    --当前的出牌人
	info.cur_play_card = nil                    --当前出的牌
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
	local room_setting = self:getPropertys("game_type","round","pay_type","seat_num","is_friend_room","is_open_voice","is_open_gps","other_setting")
	rsp_msg.room_setting = room_setting
	rsp_msg.room_id = self:get("room_id")
	rsp_msg.players = players

	self:broadcastAllPlayers("refresh_room_info",rsp_msg)
end

--像游戏服推送消息
function Room:pushEvent(node_name,player,msg_name,msg_data)
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
		log.infof("玩家[%s]不在线",user_id)
		player.disconnect = true
		self:noticePlayerDisconnect(player)
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
function Room:noticePlayerDisconnect(player)
	self:broadcastAllPlayers("notice_players_disconnect",{user_id=player.user_id,user_pos=player.user_pos})
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
	if cur_round >= 1 and pay_type == constant.PAY_TYPE.WINNER_COST then
		--因为用到了score这个变量,而这个变量只在game里面更改 所以这里需要重新拉取下redis
		self.property:reloadFromDb()
		local players = self:get("players")
		table.sort(players,function(a,b) 
				return a.score > b.score
			end)
		local player = players[1]
		local gold_num = cluster.call(player.node_name,".agent_manager","updateResource",player.user_id,"gold_num",-1*cost)
		player.gold_num = gold_num
		
		local gold_list = {{user_id = player.user_id,user_pos = player.user_pos,gold_num=gold_num}}
		self:broadcastAllPlayers("update_cost_gold",{gold_list=gold_list})
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
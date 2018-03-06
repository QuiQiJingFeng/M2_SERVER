local cluster = require "skynet.cluster"
local CONSTANT = require("constant")
local CARD_STATE = {
	KAI_PAI = 1,
	QI_PAI = 2,
	UN_SELECT = 3
}

local game = {}

function game:init(room)
	self.room = room
	self.card_list = {}
	--牛牛 没有大小王
	for card_type=1,CONSTANT.CARD_TYPE do
		for card_num=1,CONSTANT.CARD_NUM do
			local card = {card_type = card_type,card_num = card_num}
			table.insert(self.card_list,card)
		end
	end

	
end

--洗牌  FisherYates洗牌算法
--算法的思想是每次从未选中的数字中随机挑选一个加入排列，时间复杂度为O(n)
function game:fisherYates()
	math.randomseed(skynet.time())
	for i = #self.card_list,1,-1 do
		--在剩余的牌中随机取一张
		local j = math.random(i)
		--交换i和j位置的牌
		local temp = self.card_list[i]
		self.card_list[i] = self.card_list[j]
		self.card_list[j] = temp
	end
end

--向玩家推送消息
function game:sendMsg(player,proto_name,proto_data)
	cluster.call(player.node_name, palyer.service_id, "push",proto_name,proto_data)
end

function game:getPlayerByUserId(user_id)
   for _,player in ipairs(self.room.players) do
   	   if player.user_id == user_id then
   	   	  return player
   	   end
   end
end

function game:gameCMD(command,user_id,info)
	--开牌
	if command == "kaipai" then
		local player = self:getPlayerByUserId(user_id)
		if player.card_state ~= CARD_STATE.KAI_PAI then
			player.card_state = CARD_STATE.KAI_PAI
			self.room.prepare_num = self.room.prepare_num + 1
		end
    --弃牌
	elseif command == "qipai" then
		local player = self:getPlayerByUserId(user_id)
		if player.card_state ~= CARD_STATE.QI_PAI then
			player.card_state = CARD_STATE.QI_PAI
			self.room.prepare_num = self.room.prepare_num + 1
		end
	end

	if self.room.prepare_num == #self.room.players then
		--开牌
		self:kaipai()
	end
end

function game:kaipai()
	self.auto_kaipai = nil
	for index,player in ipairs(self.room.players) do
		self:sendMsg(player,"kaipai",self.card_stack)
	end
end

--如果没有在30s内开牌或弃牌完毕,则自动开牌
function game:autokaipai(time,f)
	local function t()
	    if f then
	      self:kaipai()
	    end
	  end
	 skynet.timeout(time*100, t)
end

function game:start()
	--洗牌
	self:fisherYates()

	--初始化开牌或者弃牌的数量
	self.room.prepare_num = 0
	
	self.auto_kaipai = true
	for _,player in ipairs(self.room.players) do
		--初始化玩家状态
		player.state = CARD_STATE.UN_SELECT
	end
	--发牌 
	--牛牛发5张牌
	local card_stack = {}
	for idx,player in ipairs(self.room.players) do
		if not card_stack[idx] then
			card_stack[idx] = {}
		end
		for i=1,5 do
			local card = table.remove(self.card_list,1)
			table.insert(card_stack[idx],card)
		end
	end

	for index,card in ipairs(card_stack) do
		local player = self.room.players[index]
		self:sendMsg(player,"fapai",card)
	end
	
	self.card_stack = card_stack

	self:autokaipai(time,self.auto_kaipai)

end

return game
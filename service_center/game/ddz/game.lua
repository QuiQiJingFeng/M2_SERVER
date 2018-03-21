
local skynet = require "skynet"
local Room = require "Room"
local constant = require "constant"
local ALL_CARDS = constant.ALL_CARDS
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local GAME_CMD = constant.GAME_CMD
local NET_RESULT = constant.NET_RESULT
local PLAYER_STATE = constant.PLAYER_STATE
local ZJ_MODE = constant.ZJ_MODE
local PUSH_EVENT = constant.PUSH_EVENT
local GANG_TYPE = constant.GANG_TYPE
local GAME_OVER_TYPE = constant.GAME_OVER_TYPE
local cjson = require "cjson"
local judgecard = require "ddz.judgecard"





local game = {}
local game_meta = {}
setmetatable(game,game_meta)
game.__index = game_meta
game.__newindex = game_meta

function game:clear()
	local game_meta = {}
	setmetatable(game,game_meta)
	game.__index = game_meta
	game.__newindex = game_meta
end

function game:fisherYates()
	for i = #self.card_list,1,-1 do
		--在剩余的牌中随机取一张
		local j = math.random(i)
		--交换i和j位置的牌
		local temp = self.card_list[i]
		self.card_list[i] = self.card_list[j]
		self.card_list[j] = temp
	end

	-- if constant["DEBUG"] then
	local _BHAVECONF, CARDCONF = pcall(require, "ddz/conf")

	if _BHAVECONF then
		if CARDCONF.isUserMake then
			for i = 1, 3 do 
				if CARDCONF["isOpen" ..i] then

				end
			end
		end
	end

	-- end	
end

-- 开始游戏
function game:start()
	-- 洗牌
	self:fisherYates()

	self.other_setting = self.room:get("other_setting")
	--底分
	self.base_score = self.other_setting[1]


	self.waite_operators = {}
	--当前出牌的位置
	self.cur_pos = nil

	
	-- 发牌，

	-- 叫分


end

function game:init(room_info)

	---------- 公共的，可以直接拷贝----------------
	self.room = Room.rebuild(room_info)
	local game_type = room_info.game_type

	self.card_list = {}
	local game_name = RECOVER_GAME_TYPE[game_type]
	for _,value in ipairs(ALL_CARDS[game_name]) do
		table.insert(self.card_list,value)
	end

	---------- 公共的，可以直接拷贝end----------------
	--洗牌
	self:fisherYates()

	self.other_setting = self.room:get("other_setting")
	--底分
	self.base_score = self.other_setting[1]
	--奖码数
	self.award_num = self.other_setting[2]
	--七对
	self.seven_pairs = self.other_setting[3]
	--喜分
	self.hi_point = self.other_setting[4]
	--一码不中当全中
	self.convert = self.other_setting[5]

	self.waite_operators = {}
	--当前出牌的位置
	self.cur_pos = nil





end

--更新地主的位置
function game:updateZpos()
	local zpos = nil

	local zj_mode = self.room:get("zj_mode")
	local sit_down_num = self.room:get("sit_down_num")
	if not self.zpos then
		zpos = math.random(1,sit_down_num)
	else
		zpos = self.zpos
	end
	self.zpos = zpos
end

function game:start()
	--1、更新庄家的位置（斗地主流程要改动）
	self:updateZpos()

	local players = self.room:get("players")
	--2、发牌
	local deal_num = 13 --红中麻将发13张牌
	local players = self.room:get("players")
	for index=1,self.room:get("sit_down_num") do
		local cards = {}
		for j=1,deal_num do
			--从最后一个开始移除,避免大量的元素位置重排
			local card = table.remove(self.card_list) 
			table.insert(cards,card)
		end

		local player = self.room:getPlayerByPos(index)
		player.card_list = cards
		local rsp_msg = {zpos = self.zpos,cards = cards}
		self.room:sendMsgToPlyaer(player,PUSH_EVENT.DEAL_CARD,rsp_msg)
	end

	--3、将card按类别和数字存储
	for _,player in ipairs(players) do
		local card_list = player.card_list

		local handle_cards = { }
		for i= 1,4 do
			handle_cards[i] = {}
			for j= 1,10 do
				handle_cards[i][j] = 0
			end
		end

		for _,value in ipairs(card_list) do
			local card_type = math.floor(value / 10) + 1
			local card_value = value % 10
			handle_cards[card_type][10] = handle_cards[card_type][10] + 1
			handle_cards[card_type][card_value] = handle_cards[card_type][card_value] + 1
		end
		player.handle_cards = handle_cards
	end
	
	for i,player in ipairs(players) do
		self.waite_operators[player.user_id] = "DEAL_FINISH"
	end
end





return game

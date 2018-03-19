
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
local judgecard = require "hzmj.judgecard"





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







return game

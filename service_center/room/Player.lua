local pbc = require "protobuf"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local utils = require "utils"
local skynet = require "skynet"

local Player = {}

Player.__index = Player

function Player.new(info)
	local player = {}
	setmetatable(player, Player)
	player.__index = Player
	player:init(info)

	return player
end

function Player:init(info)
	self.user_id = info.user_id                --玩家的ID
	self.user_name = info.user_name            --玩家的名称
	self.user_pic = info.user_pic              --玩家头像的url
	self.user_ip = info.user_ip                --玩家IP
	self.secret = info.secret                  --秘钥
	self.score = info.score or 0               --积分
	self.cur_score = 0                         --当前局的积分
	self.fd = info.fd                          --玩家的fd
	self.gold_num = info.gold_num	           --玩家的金币数量
	self.user_pos = info.user_pos
	self.is_sit = info.is_sit
    self.hu_num = 0
    self.ming_gang_num = 0
    self.an_gang_num = 0
    self.reward_num = 0
    self.disconnect = false
    self.put_cards = {}
end

function Player:update(info)
    utils:mergeToTable(self,info)
end

function Player:send(data_content)
    local room = require "room"
    if room.replay_id then
        skynet.send(".replay_cord","lua","insertRecord",room.replay_id,data_content)
    end

    if self.disconnect then
        return
    end

    print(cjson.encode(data_content))

    -- 转换为protobuf编码
    local success, data, err = pcall(pbc.encode, "S2C", data_content)
    if not success or err then
        print("encode protobuf error",cjson.encode(data_content))
        return
    end
    
    -- 根据密钥进行加密
    local secret = self.secret
    if data and secret then
        success, data = pcall(crypt.desencode, secret, data)
        if not success then
            print("desencode error")
            return
        end
    end
    -- 拼接包长后发送
    socket.write(self.fd, string.pack(">s2", crypt.base64encode(data)))
end

return Player
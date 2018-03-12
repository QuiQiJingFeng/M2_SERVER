local skynet = require "skynet"
local redis = require "skynet.db.redis"
local cjson = require "cjson"
local cluster = require "skynet.cluster"
local redis_manager = require "redis_manager"
local user_info = {}

function user_info:init(info)
	self.fd = info.fd
	self.secret = info.secret
	self.user_id = info.user_id
	self.session_id = 0
    self.user_name = info.user_name
    self.user_pic = info.user_pic
	--最后通讯时间
	user_info.last_check_time = nil
end

function user_info:clear()
	for k,v in pairs(user_info) do
        user_info[k] = nil
    end
end

function user_info:getRedis()
    return redis_manager:connectCenterRedis()
end

function user_info:loadfromDb()
    local center_redis = self:getRedis()
    --加载数据
    local user_info_key = "info:"..self.user_id
    self.user_info_key = user_info_key
    if not center_redis:exists(user_info_key) then
        center_redis:disconnect()
        return false
    end

    local data = center_redis:hgetall("info:"..self.user_id)
    for i = 1, #data, 2 do
        local module, name = string.match(data[i], "([%w_]+):([%w_]+)")
        local value = data[i+1]
        if module == "resource" then

        end
    end
    center_redis:disconnect()
end

function user_info:leaveRoom()
    local room_id = user_info:hgetData(user_info.user_info_key,"room_id")
    local user_id = self.user_id
    local center_node = self:getTargetNodeByRoomId(room_id)
    if not center_node then
        return true
    end
    local result = cluster.call(center_node,".room_manager","leaveRoom",room_id,user_id)
    --清理绑定的room_id
    print("FYD  清理")
    self:hdelData(self.user_info_key,"room_id",room_id)
    return result
end

function user_info:getTargetNodeByRoomId(room_id)
    local center_redis = self:getRedis()
    local center_node = center_redis:hget("room_list",room_id)
    center_redis:disconnect()
    return center_node
end

function user_info:setData(key,value)
    local center_redis = self:getRedis()
    center_redis:set(key,value)
    center_redis:disconnect()
end

function user_info:hdelData(key1,key2)
    local center_redis = self:getRedis()
    center_redis:hdel(key1,key2)  
    center_redis:disconnect()
end

function user_info:hsetData(key1,key2,value)
    local center_redis = self:getRedis()
    print("key1,key2,value --->",key1,key2,value)
    center_redis:hset(key1,key2,value)  
    center_redis:disconnect()
end

function user_info:hgetData(key1,key2)
    local center_redis = self:getRedis()
    local data = center_redis:hget(key1,key2)
    center_redis:disconnect()
    return data
end

return user_info
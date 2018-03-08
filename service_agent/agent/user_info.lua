local skynet = require "skynet"
local redis = require "skynet.db.redis"
local cjson = require "cjson"
local cluster = require "skynet.cluster"

local user_info = {}

function user_info:init(info)
	self._fd = info.fd
	self._secret = info.secret
	self._user_id = info.user_id
	self._session_id = 0
	--最后通讯时间
	user_info._last_check_time = nil
end

function user_info:clear()
	for k,v in pairs(user_info) do
        user_info[k] = nil
    end
end

function user_info:getRedis()
    local center_redis_address = skynet.getenv("center_redis")
    local address, port = string.match(center_redis_address, "([%d%.]+):([%d]+)")
    local center_redis = redis.connect({ host = address, port = port })
    return center_redis
end

function user_info:loadfromDb()
    local center_redis = self:getRedis()
    --加载数据
    local user_info_key = "info:"..self._user_id
    self._user_info_key = user_info_key
    if not center_redis:exists(user_info_key) then
        center_redis:disconnect()
        return false
    end

    local data = center_redis:hgetall("info:"..self._user_id)
    for i = 1, #data, 2 do
        local module, name = string.match(data[i], "([%w_]+):([%w_]+)")
        local value = data[i+1]
        if module == "resource" then

        end
    end
    center_redis:disconnect()
end

function user_info:leaveRoom()
    local room_id = user_info:hgetData(user_info._user_info_key,"room_id")
    local user_id = self._user_id
    local target_node = self:getTargetNodeByRoomId(room_id)
    local result = cluster.call(target_node,".room_manager","leaveRoom",room_id,user_id)
    --清理绑定的room_id
    print("FYD  清理")
    self:hdelData(self._user_info_key,"room_id",room_id)
    return result
end

function user_info:getTargetNodeByRoomId(room_id)
    local center_redis = self:getRedis()
    local target_node = center_redis:hget("room_list",room_id)
    return target_node
end

function user_info:setData(key,value)
    local center_redis = self:getRedis()
    center_redis:set(key,value)
end

function user_info:hdelData(key1,key2)
    local center_redis = self:getRedis()
    center_redis:hdel(key1,key2)  
end

function user_info:hsetData(key1,key2,value)
    local center_redis = self:getRedis()
    center_redis:hset(key1,key2,value)  
end

function user_info:hgetData(key1,key2)
    local center_redis = self:getRedis()
    return center_redis:hget(key1,key2)
end

return user_info
local redis = require "skynet.db.redis"
local skynet = require "skynet"
local redis_manager = {}

local conf = {}
local host, port = string.match(skynet.getenv("center_redis"), "([%d%.]+):([%d]+)")
conf["CENTER_REDIS"] = {host = host, port = port}

--连接center服
function redis_manager:connectCenterRedis()
    return redis.connect(conf["CENTER_REDIS"])
end


return redis_manager
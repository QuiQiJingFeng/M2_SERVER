local RedisManager = {}

function RedisManager:init()
	local host, port = string.match(skynet.getenv("center_redis"), "([%d%.]+):([%d]+)")
	self.conf = {}
	self.conf["CENTER_REDIS"] = {host = host, port = port}
end

--连接center服
function RedisManager:connectCenterRedis()
    return redis.connect(self.conf["CENTER_REDIS"])
end


return RedisManager
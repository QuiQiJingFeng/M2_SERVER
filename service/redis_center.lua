local skynet = require "skynet"
require "skynet.manager"
local redis = require "skynet.db.redis"
local log = require "skynet.log"
local sharedata = require "skynet.sharedata"
local utils = require "utils"
local cjson = require "cjson"

local redis_list = {}
local REDIS_INDEX = 1
local REDIS_NUM = 10
local redis_db = nil

local CMD = {}


--DEL key 删除一个key
function CMD.DEL(id,key)
	redis_db:SELECT(id)
	return redis_db:DEL(key)
end

function CMD.GET(id,key)
	redis_db:SELECT(id)
	return redis_db:GET(key)
end

function CMD.SET(id,key,value)
	redis_db:SELECT(id)
	return redis_db:SET(key,value)
end

------------------------------------------------------------
-----------------------------字符串操作------------------------
------------------------------------------------------------

--SET key value 设置指定 key 的值
function CMD.SET(id,key,value)
	redis_db:SELECT(id)
	return redis_db:SET(key,value)
end

--GETSET key value 将给定 key 的值设为 value ，并返回 key 的旧值(old value)
function CMD.GETSET(id,key,value)
	redis_db:SELECT(id)
	return redis_db:GETSET(key,value)
end

--MGET key1 [key2..] 获取所有(一个或多个)给定 key 的值
function CMD.MGET(id,...)
	redis_db:SELECT(id)
	return redis_db:MGET(key,...)
end

--SETEX key seconds value 将值 value 关联到 key 
--并将 key 的过期时间设为 seconds (以秒为单位)
function CMD.SETEX(id,key,seconds,value)
	redis_db:SELECT(id)
	return redis_db:SETEX(key,seconds,value)
end

--MSET key value [key value ...] 同时设置一个或多个 key-value 对。
function CMD.MSET(id,...)
	redis_db:SELECT(id)
	return redis_db:MSET(...)
end

--PSETEX key milliseconds value 
--这个命令和 SETEX 命令相似，但它以毫秒为单位设置 key 的生存时间，
--而不是像 SETEX 命令那样，以秒为单位
function CMD.PSETEX(id,key,milliseconds,value)
	redis_db:SELECT(id)
	return redis_db:PSETEX(key,milliseconds,value)
end

--INCR key 将 key 中储存的数字值增一
function CMD.INCR(id,key)
	redis_db:SELECT(id)
	return redis_db:INCR(key)
end

--INCRBY key increment 将 key 所储存的值加上给定的增量值（increment） 
function CMD.INCRBY(id,key,increment)
	redis_db:SELECT(id)
	return redis_db:INCRBY(key,increment)
end

--DECR key 将 key 中储存的数字值减一
function CMD.DECR(id,key)
	redis_db:SELECT(id)
	return redis_db:DECR(key)
end

--DECRBY key decrement key 所储存的值减去给定的减量值（decrement） 
function CMD.DECRBY(id,key,decrement)
	redis_db:SELECT(id)
	return redis_db:DECR(key,decrement)
end

------------------------------------------------------------
----------------------------哈希表操作------------------------
------------------------------------------------------------
--HDEL key field2 [field2] 删除一个或多个哈希表字段
function CMD.HDEL(id,key,...)
	redis_db:SELECT(id)
	return redis_db:HDEL(key,...)
end

--HEXISTS key field 查看哈希表 key 中，指定的字段是否存在
function CMD.HEXISTS(id,key,field)
	redis_db:SELECT(id)
	return redis_db:HEXISTS(key,field)
end

--HGET key field 获取存储在哈希表中指定字段的值
function CMD.HGET(id,key,field)
	redis_db:SELECT(id)
	return redis_db:HGET(key,field)
end

--	HGETALL key 获取在哈希表中指定 key 的所有字段和值
function CMD.HGETALL(id,key)
	redis_db:SELECT(id)
	return redis_db:HGETALL(key)
end

--HINCRBY key field increment 为哈希表 key 中的指定字段的整数值加上增量 increment 
function CMD.HINCRBY(id,key,field,increment)
	redis_db:SELECT(id)
	return redis_db:HINCRBY(key,field,increment)
end

--HINCRBYFLOAT key field increment 为哈希表 key 中的指定字段的浮点数值加上增量 increment
function CMD.HINCRBYFLOAT(id,key,field,increment)
	redis_db:SELECT(id)
	return redis_db:HINCRBYFLOAT(key,field,increment)
end

--HKEYS key 获取所有哈希表中的字段
function CMD.HKEYS(id,key)
	redis_db:SELECT(id)
	return redis_db:HKEYS(key)
end

--HLEN key 获取哈希表中字段的数量
function CMD.HLEN(id,key)
	redis_db:SELECT(id)
	return redis_db:HLEN(key)
end

--HMGET key field1 [field2] 获取所有给定字段的值
function CMD.HMGET(id,key,...)
	redis_db:SELECT(id)
	return redis_db:HMGET(key,...)
end

--HMSET key field1 value1 [field2 value2 ] 
--同时将多个 field-value (域-值)对设置到哈希表 key 中
function CMD.HMSET(id,key,...)
	redis_db:SELECT(id)
	return redis_db:HMSET(key,...)
end


--HSET key field value 将哈希表 key 中的字段 field 的值设为 value
function CMD.HSET(id,key,filed,value)
	redis_db:SELECT(id)
	return redis_db:HSET(key,filed,value)
end

--HSETNX key field value 只有在字段 field 不存在时，设置哈希表字段的值
function CMD.HSETNX(id,key,filed,value)
	redis_db:SELECT(id)
	return redis_db:HSETNX(key,filed,value)
end

--	HVALS key 获取哈希表中所有值
function CMD.HVALS(id,key)
	redis_db:SELECT(id)
	return redis_db:HVALS(key)
end







------------------------------------------------------------
-----------------------------集合操作------------------------
------------------------------------------------------------

--SADD key member1 [member2] 向集合添加一个或多个成员
function CMD.SADD(id,key,...)
	redis_db:SELECT(id)
	return redis_db:SADD(key,...)
end

--SCARD key 获取集合的成员数
function CMD.SCARD(id,key)
	redis_db:SELECT(id)
	return redis_db:SCARD(key)
end

--SDIFF key1 [key2] 返回给定所有集合的差集
function CMD.SDIFF(id,key1,key2)
	redis_db:SELECT(id)
	return redis_db:SDIFF(key1,key2)
end

--SDIFFSTORE destination key1 [key2] 
--返回给定所有集合的差集并存储在 destination 中
function CMD.SDIFFSTORE(id,destination,...)
	redis_db:SELECT(id)
	return redis_db:SDIFFSTORE(destination,...)
end

--SINTER key1 [key2] 返回给定所有集合的交集
function CMD.SINTER(id,...)
	redis_db:SELECT(id)
	return redis_db:SINTER(...)
end

--SINTERSTORE destination key1 [key2] 返回给定所有集合的交集并存储在 destination 中
function CMD.SINTERSTORE(id,destination,...)
	redis_db:SELECT(id)
	return redis_db:SINTERSTORE(destination,...)
end

--SISMEMBER key member 判断 member 元素是否是集合 key 的成员存在返回1,否则返回0
function CMD.SISMEMBER(id,key,member)
	redis_db:SELECT(id)
	return redis_db:SISMEMBER(key,member)
end

--SMEMBERS key 返回集合中的所有成员
function CMD.SMEMBERS(id,key)
	redis_db:SELECT(id)
	return redis_db:SMEMBERS(key)
end

--SMOVE source destination member 
--将 member 元素从 source 集合移动到 destination 集合
function CMD.SMOVE(id,source,destination,member)
	redis_db:SELECT(id)
	return redis_db:SMOVE(source,destination,member)
end

--SPOP key 移除并返回集合中的一个随机元素
function CMD.SPOP(id,key)
	redis_db:SELECT(id)
	return redis_db:SPOP(key)
end

--SRANDMEMBER key [count] 返回集合中一个或多个随机元素
function CMD.SRANDMEMBER(id,key)
	redis_db:SELECT(id)
	return redis_db:SRANDMEMBER(key)
end

--SREM key member1 [member2] 移除集合中一个或多个成员
function CMD.SREM(id,key,...)
	redis_db:SELECT(id)
	return redis_db:SREM(key,...)
end

--SUNION key1 [key2] 返回所有给定集合的并集
function CMD.SUNION(id,...)
	redis_db:SELECT(id)
	return redis_db:SUNION(...)
end

--SUNIONSTORE destination key1 [key2] 所有给定集合的并集存储在 destination 集合中
function CMD.SUNIONSTORE(id,destination,...)
	redis_db:SELECT(id)
	return redis_db:SUNIONSTORE(destination,...)
end






------------------------------------------------------------
-----------------------------列表操作------------------------
------------------------------------------------------------
--LINSERT key BEFORE|AFTER pivot value
--将值 value 插入到列表 key 当中，位于值 pivot 之前或之后
function CMD.LINSERT(id,key,mod,pivot,value)
	redis_db:SELECT(id)
	return redis_db:LINSERT(key,mod,pivot,value)
end

--LPUSH key value1,value2
function CMD.LPUSH(id,key,...)
	redis_db:SELECT(id)
	return redis_db:LPUSH(key,...)
end

--RPUSH key value1,value2
function CMD.RPUSH(id,key,...)
	redis_db:SELECT(id)
	return redis_db:RPUSH(key,...)
end

--CUSTOM 列表移除
function CMD.LREMOVE(id,key,pos)
	redis_db:SELECT(id)
	redis_db:MULTI()
    redis_db:LSET(self.list_key,pos-1,"__deleted__")
    redis_db:LREM(self.list_key,1,"__deleted__")
    local ret = self._redis:EXEC()
    local errors = ""
    for i, v in ipairs(ret) do
        if not (type(v) == "number" or v == "OK" ) then
            errors = errors .. v
        end
    end
    if errors ~= "" then
    	log.warningf("列表[%s]移除失败 pos=[%d]\n error=[%s]",key,pos,errors)
    end
end

--LPOP
function CMD.LPOP(id,key)
	redis_db:SELECT(id)
	return redis_db:LPOP(key)
end

--RPOP
function CMD.RPOP(id,key)
	redis_db:SELECT(id)
	return redis_db:RPOP(key)
end

--LTRIM
function CMD.LTRIM(id,key,start,stop)
	redis_db:SELECT(id)
	return redis_db:LTRIM(key,start,stop)
end

--LSET key index value
function CMD.LSET(id,key,index,value)
	redis_db:SELECT(id)
	return redis_db:LSET(key,index,value)
end

--LRANGE key start stop
function CMD.LRANGE(id,key,start,stop)
	redis_db:SELECT(id)
	return redis_db:LRANGE(key,start,stop)
end


----------------------CUSTOM-------

function CMD.GetRoomKeysForNodeName(id,node_name)
	redis_db:SELECT(id)
	local room_keys = {}
 	--room_list:room:user_id
	local filter = "room:*"
	local all_keys = redis_db:keys(filter)
	for _,room_info_key in ipairs(all_keys) do
		local name = redis_db:HGET(room_info_key,"node_name") or {}
		--获取所有在node_name机器上创建的房间
		if name == node_name.."__S__" then
			table.insert(room_keys,room_info_key)
		end
	end
	return room_keys
end

--获取user_id，如果没有则新建一个
function CMD.ProcessLogin(id,user_key,reconnect_token)
	redis_db:select(id)
	local user_id = redis_db:GET(user_key)
	if not user_id then
		local max_id = redis_db:incrby("user_id_generator", 1)
        user_id = utils:createUserid(max_id)
        redis_db:set(user_key,user_id)
	end
	redis_db:hset("info:"..user_id, "reconnect_token", reconnect_token)

	return user_id
end

--
function CMD.ProcessReconnect(id,info_key,filed,client_token,new_token)
	redis_db:select(id)
	local server_token = redis_db:hget(info_key,filed)
	if server_token ~= client_token then
		return false
	end

 	redis_db:hset(info_key,"reconnect_token",new_token)
 	return true
end


local function updateIndex()
	REDIS_INDEX = REDIS_INDEX + 1
	if REDIS_INDEX > REDIS_NUM then
		REDIS_INDEX = 1
	end
	redis_db = redis_list[REDIS_INDEX]
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        if f then
        	updateIndex()
        	skynet.ret(skynet.pack(f(...)))
        else
        	log.error("UNKOWN COMMAND :"..command)
        end
    end)


    --开10个redis 连接
    local host, port = string.match(skynet.getenv("center_redis"), "([%d%.]+):([%d]+)")
    for i=1,REDIS_NUM do
    	local db = redis.connect({host = host, port = port})
    	redis_list[i] = db
    end

    skynet.register(".redis_center")
end)

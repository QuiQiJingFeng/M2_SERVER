local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
	--本手机没有手机卡,但是有通讯录，我们可以直接打网络电话,但是别人却无法打电话过来

	-- query name "sdb" of cluster db.  查询db节点的.sdb服务
	local sdb = cluster.query("db", ".sdb")
	--创建其他节点的本地代理
	local proxy = cluster.proxy("db", sdb)
	local largekey = string.rep("X", 128*1024)
	local largevalue = string.rep("R", 100 * 1024)
	--通过本地代理向其他节点的监听模块发送信息
	print(skynet.call(proxy, "lua", "SET", "largekey", "largevalue"))
	local v = skynet.call(proxy, "lua", "GET", "largekey")
	assert("largevalue" == v)
	skynet.send(proxy, "lua", "PING", "proxy")

	print(cluster.call("db", sdb, "GET", "a"))
	print(cluster.call("db2", sdb, "GET", "b"))
	cluster.send("db2", sdb, "PING", "db2:longstring" .. "largevalue")

	-- test snax service
	local pingserver = cluster.snax("db", "pingserver")
	print(pingserver.req.ping "hello")
end)

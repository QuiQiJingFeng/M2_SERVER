local skynet = require "skynet"
local cluster = require "skynet.cluster"
local snax = require "skynet.snax"

skynet.start(function()
	--代码中可以动态加载,也可以在config中配置 通讯录列表
	-- cluster.reload {
	-- 	db = "127.0.0.1:2528",
	-- 	db2 = "127.0.0.1:2529",
	-- }

	local sdb = skynet.newservice("simpledb")
	-- register name "sdb" for simpledb, you can use cluster.query() later.
	-- See cluster2.lua
	cluster.register(".sdb", sdb)

	print(skynet.call(sdb, "lua", "SET", "a", "FHQYDIDX"))
	print(skynet.call(sdb, "lua", "SET", "b", "FYD13526132915"))
	print(skynet.call(sdb, "lua", "GET", "a"))
	print(skynet.call(sdb, "lua", "GET", "b"))
	--如果需要能够接收到其他手机发来的信息,那么至少需要有一个手机卡(这里开了两块)
	cluster.open "db"
	cluster.open "db2"

	-- unique snax service
	snax.uniqueservice "pingserver"
end)

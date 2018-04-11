local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

skynet.start(function()
	log.info("Server start")

	skynet.uniqueservice("debug_console",9000)

	skynet.uniqueservice("static_data")

	skynet.uniqueservice("replay_cord")

	skynet.uniqueservice("mysql_pool")

	skynet.uniqueservice("redis_center")

	skynet.uniqueservice("agent_manager")
	
	skynet.exit()
end)

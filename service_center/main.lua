local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

skynet.start(function()
	log.info("Server start")
	local console_port = skynet.getenv("console_port")
	skynet.uniqueservice("debug_console",console_port)

	skynet.uniqueservice("static_data")

	skynet.uniqueservice("replay_cord")

	skynet.uniqueservice("mysql_pool")

	skynet.uniqueservice("redis_center")

	skynet.uniqueservice("agent_manager")
	
	skynet.exit()
end)

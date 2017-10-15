local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

skynet.start(function()
	log.info("Server start")

	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.uniqueservice("debug_console",8000)

	skynet.uniqueservice("agent_manager")

	skynet.uniqueservice("cluster_manager")

	skynet.exit()
end)

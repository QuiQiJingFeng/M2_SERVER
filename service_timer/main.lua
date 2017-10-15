local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

skynet.start(function()
	log.info("Server start")

    skynet.uniqueservice("timer")

	skynet.uniqueservice("cluster_manager")

	skynet.exit()
end)

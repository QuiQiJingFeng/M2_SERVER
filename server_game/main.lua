local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

skynet.start(function()
	log.info("Game Server Start")
	skynet.uniqueservice("agent_manager")
	skynet.exit()
end)

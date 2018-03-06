local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
	print("cluster manager start!!!")
	if not skynet.getenv "daemon" then
		-- local console = skynet.newservice("console")
	end
	skynet.uniqueservice("debug_console",7000)
	skynet.uniqueservice("cluster_manager")

	skynet.exit()
end)

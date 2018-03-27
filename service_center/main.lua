local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log  =require "skynet.log"

local function bindCluster()
	local node_type = skynet.getenv("node_type")
    local node_name = skynet.getenv("node_name")
    local node_address = skynet.getenv("node_address")

    local cluster_config = cluster.call("common_server", ".cluster_manager", "addNode", node_type, node_name, node_address)
    cluster.reload(cluster_config)
    cluster.open(node_name)
end

skynet.start(function()
	log.info("Server start")

	skynet.uniqueservice("debug_console",9000)

	skynet.uniqueservice("static_data")

	skynet.uniqueservice("replay_cord")
	skynet.uniqueservice("redis_center")

	skynet.uniqueservice("room_manager") 

	bindCluster()


	

	skynet.exit()
end)

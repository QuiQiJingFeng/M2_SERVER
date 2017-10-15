local skynet = require "skynet"
local log = require "skynet.log"
local cluster = require "skynet.cluster"

require "skynet.manager"

local CMD = {}
local self_info = {}
local node_map = {}

function CMD.reload()
    log.info("start")
    local cluster_config = {}
    for node_type, node_list in pairs(node_map) do
        log.infof("type: %s", node_type)
        for _,node_info in ipairs(node_list) do
            log.infof("node: %s，%s", node_info.node_name, node_info.node_address)
            cluster_config[node_info.node_name] = node_info.node_address
        end
    end
    
    cluster.reload(cluster_config)
end

function CMD.self()
    return self_info.node_name
end

function CMD.addNode(node_type, node_name, node_address)
    node_map[node_type] = node_map[node_type] or {}
    table.insert(node_map[node_type], {node_name = node_name, node_address = node_address})

    CMD.reload()
end

function CMD.removeNode(node_type, node_name)
    if node_map[node_type] then
        if node_map[node_type][node_name] then
            node_map[node_type][node_name] = nil
            CMD.reload()
        else
            log.errorf("no node name: %s", node_name)
        end
    else
        log.errorf("no node type: %s", node_type)
    end
end

function CMD.pickNode(node_type)
    if node_map[node_type] then
        local size = #node_map[node_type]
        if size > 0 then
            return node_map[node_type][math.random(size)].node_name
        end
    else
        log.errorf("no node type: %s", node_type)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)

    self_info = {}
    self_info.node_type = skynet.getenv("node_type")
    self_info.node_name = skynet.getenv("node_name")
    self_info.node_address = skynet.getenv("node_address")

    CMD.addNode(self_info.node_type, self_info.node_name, self_info.node_address)

    cluster.open(self_info.node_name)

    skynet.register(".cluster_manager")
end)

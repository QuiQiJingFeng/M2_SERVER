local skynet = require "skynet"
local log = require "skynet.log"
local cluster = require "skynet.cluster"

require "skynet.manager"

local CMD = {}
local node_map = {}

function CMD.reload(ignore_node_name)
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

    --通知所有的结点进行更新
    for node_name,v in pairs(cluster_config) do
        if node_name ~= skynet.getenv("node_name") then
            if not (ignore_node_name and ignore_node_name == node_name) then
                cluster.call(node_name, ".clusterd", "reload", cluster_config)
            end
        end
    end
    
    return cluster_config
end


function CMD.addNode(node_type, node_name, node_address)
    node_map[node_type] = node_map[node_type] or {}
    local new_node = {node_name = node_name, node_address = node_address}
    for index,node in pairs(node_map[node_type]) do
        if node.node_name == node_name then
            table.remove(node_map[node_type],index)
            break
        end
    end
    table.insert(node_map[node_type], {node_name = node_name, node_address = node_address})

    return CMD.reload(node_name)
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

    local config = {}
    config.node_type = skynet.getenv("node_type")
    config.node_name = skynet.getenv("node_name")
    config.node_address = skynet.getenv("node_address")
    CMD.addNode(config.node_type, config.node_name, config.node_address)
    cluster.open(config.node_name)

    skynet.register(".cluster_manager")
end)

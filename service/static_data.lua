local skynet = require "skynet"
require "skynet.manager"
local sharedata = require "skynet.sharedata"
local constant = require "constant"

local FUNCTION = {}

--刷新config文件的配置
FUNCTION["REFRESH_CONFIG"] = function()
    local node_type = skynet.getenv("node_type")
    local node_name = skynet.getenv("node_name")
    local node_address = skynet.getenv("node_address")
    local server_info = {node_type=node_type,node_name=node_name,node_address=node_address}
    sharedata.update("server_info",server_info)

    local center_redis = skynet.getenv("center_redis")
    local host, port = string.match(center_redis, "([%d%.]+):([%d]+)")
    local redis_conf = {host=host,port=port}
    sharedata.update("redis_conf",redis_conf)

    local center_mysql = skynet.getenv("center_mysql")
    local host, port = string.match(center_mysql, "([%d%.]+):([%d]+)")
    local mysql_conf = {host=host,port=port}
    sharedata.update("mysql_conf",mysql_conf)

end

--刷新常量配置表
FUNCTION["REFRESH_CONSTANT"] = function()
    sharedata.update("constant",constant)
end


skynet.start(function()
    
    for _,func in pairs(FUNCTION) do
        func()
    end

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(FUNCTION[cmd])
        f(...)
    end)
    skynet.register(".config")
end)

local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local redis = require "skynet.db.redis"
local pbc = require "protobuf"
local cjson = require "cjson"

local CENTER_REDIS
local CMD = {}

local user_info = require("user_info")

local event_handler = require "event_handler"
local logic = {}

-- 分配给用户后调用此方法，设置用户相关数据
function CMD.start(info)
    -- 初始化用户数据
    user_info:init(info)
end

-- 逻辑上此agent之后不再与用户相关，可以被重新分配给用户
function CMD.free()
    -- 重置用户相关数据
    user_info:clear()
end

--断开连接
function CMD.disconnect()
    user_info:userDisconnect()
end

-- 请求处理函数
function CMD.request(data_content)
    -- 获取数据包中的各项值
    local session_id, req_name, req_msg
    for key, value in pairs(data_content) do
        if key == "session_id" then
            session_id = value
        else
            req_name, req_msg = key, value
        end
    end

    if req_name == "heartbeat" then
        -- 心跳包直接回发
        user_info:send(data_content)
    elseif session_id then

        -- 请求包的session_id如果大于当前记录值，视为新请求，否则视为客户端重发数据包
        if user_info.session_id < session_id then
            -- 记录新包的session_id
            user_info.session_id = session_id

            -- 根据请求包包名分发处理
            local rsp_name, rsp_msg = event_handler:emit(req_name, req_msg)
            if rsp_name then
                -- 以请求包的session_id组装回包
                local send_data = {["session_id"] = session_id, [rsp_name] = rsp_msg}
                
                -- 发送并记录回包
                user_info:send(send_data)
            else
                -- 理论上所有的请求包都有对应回包，走到这里在逻辑上是不正常的
                log.errorf("no respone for request: %s", req_msg)
            end
        else
            --TODO
            -- 从包缓存中根据session_id获取回包缓存，如果有，直接回发不再重复处理
        end
    end
end

-- 推送包
function CMD.push(push_name, push_msg)
    local send_data = {[push_name] = push_msg}
    user_info:send(send_data)
end

function CMD.debugProto(proto_name,proto_msg)
    proto_msg = cjson.decode(proto_msg)
    local rsp_name, rsp_msg = event_handler:emit(proto_name,proto_msg)
    return cjson.encode({rsp_name,rsp_msg})
end

local function init_logic()
    local user = require("logic.user")
    user:init()
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)

    init_logic()

    -- 初始化protobuf协议
    pbc.register_file(skynet.getenv("protobuf"))
end)

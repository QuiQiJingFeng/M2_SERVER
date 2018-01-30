local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local redis = require "skynet.db.redis"
local pbc = require "protobuf"
local cjson = require "cjson"

local CMD = {}

local self_info = {}

local event_handler = require "event_handler"
local logic = {}

local RECORD_MSG_TYPE = {
    REQ = "req",
    RSP = "rsp",
    PUSH = "push",
    RERSP = "rersp",
}
local function record_msg(msg_type, data_content)
    local now = skynet.time()
    -- 记录收发包
    local date = os.date("%Y-%m-%d", math.ceil(now))
    local time = os.date("%H:%M:%S", math.ceil(now))

    local record = {}
    record.time = time
    record.type = msg_type
    record.data = data_content

    local success, str = pcall(cjson.encode, record)
    if success then
        self_info.redis:lpush(self_info.user_id .. ":history:" .. date, str)
    else
        log.error(str)
    end
end

local function send(data_content)
    -- 转换为protobuf编码
    local success, data, err = pcall(pbc.encode, "S2C", data_content)
    if not success or err then
        log.error("encode protobuf error")
        return
    end

    -- 根据密钥进行加密
    if data and self_info.secret then
        success, data = pcall(crypt.desencode, self_info.secret, data)
        if not success then
            log.error("desencode error")
            return
        end
    end

    -- 拼接包长后发送
    socket.write(self_info.fd, string.pack(">s2", crypt.base64encode(data)))
end

local function checkheartbeat(user_id)
    -- 判断定时器的设置者跟当前用户为同一个人，防止agent被重新分配后定时器未取消造成的异常
    if user_id == self_info.user_id then
        if skynet.time() - self_info.last_check_time > 300 then
            skynet.send(".agent_manager", "lua", "close", self_info.fd)
        else
            local user_id = self_info.user_id
            skynet.timeout(40 * 100, function() checkheartbeat(user_id) end)
        end
    end
end

-- 分配给用户后调用此方法，设置用户相关数据
function CMD.start(info, is_reconnect)
    -- 初始化用户数据
    self_info = info

    -- 简历redis连接
    local redis_address = skynet.getenv("redis_address")
    local address, port = string.match(redis_address, "([%d%.]+):([%d]+)")
    self_info.redis = redis.connect({ host = address, port = port })

    -- 定时心跳检查
    self_info.last_check_time = skynet.time()
    checkheartbeat(self_info.user_id)

    -- 初始化包缓存，如果是重连用户，则从redis加载上一次断线后的包缓存
    self_info.send_data_map = {}
    self_info.session_id = 0
    if is_reconnect then
        local send_data_str = self_info.redis:hget(self_info.user_id, "send_data_map")
        if send_data_str then
            self_info.send_data_map = cjson.decode(send_data_str)
        end
    end
    -- 删除redis中的包缓存记录
    self_info.redis:hdel(self_info.user_id, "send_data_map")
end

-- 逻辑上此agent之后不再与用户相关，可以被重新分配给用户
function CMD.free()
    -- 将包缓存吸入redis
    self_info.redis:hset(self_info.user_id, "send_data_map", cjson.encode(self_info.send_data_map))

    -- 断开redis连接
    self_info.redis:disconnect()

    -- 重置用户相关数据
    self_info = {}
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
        send(data_content)
    elseif session_id then
        -- 记录请求包
        record_msg(RECORD_MSG_TYPE.REQ, data_content)

        -- 请求包的session_id如果大于当前记录值，视为新请求，否则视为客户端重发数据包
        if self_info.session_id < session_id then
            -- 先删除旧session_id缓存的包
            self_info.send_data_map[tostring(session_id)] = nil

            -- 记录新包的session_id
            self_info.session_id = session_id

            -- 根据请求包包名分发处理
            local rsp_name, rsp_msg = event_handler:emit(req_name, req_msg)
            if rsp_name then
                -- 以请求包的session_id组装回包
                local send_data = {["session_id"] = session_id, [rsp_name] = rsp_msg}
                
                -- 发送并记录回包
                send(send_data)
                record_msg(RECORD_MSG_TYPE.RSP, send_data)

                -- 缓存
                self_info.send_data_map[tostring(session_id)] = send_data
            else
                -- 理论上所有的请求包都有对应回包，走到这里在逻辑上是不正常的
                log.errorf("no respone for request: %s", req_msg)
            end
        else
            -- 从包缓存中根据session_id获取回包缓存，如果有，直接回发不再重复处理
            local send_data = self_info.send_data_map[tostring(session_id)]
            if send_data then
                -- 发送并记录回包
                send(send_data)
                record_msg(RECORD_MSG_TYPE.RERSP, send_data)
            else
                -- 理论上所有的请求包都有对应回包，走到这里在逻辑上是不正常的
                log.errorf("no respone cache for request: %s", req_msg)
            end
        end
    end

    -- 更新最后通讯时间
    self_info.last_check_time = skynet.time()
end

-- 推送包
function CMD.push(push_name, push_msg)
    local send_data = {[push_name] = push_msg}
    record_msg(RECORD_MSG_TYPE.PUSH, send_data)
    send(send_data)
end

local function init_logic()
    -- agent自身的初始准备工作，与具体用户无关
    logic.user = require "logic.user"

    for _,logic_item in pairs(logic) do
        logic_item.init(self_info)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)

    -- 初始化protobuf协议
    pbc.register_file(skynet.getenv("protobuf"))

    -- 初始化
    init_logic()
end)

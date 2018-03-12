local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local pbc = require "protobuf"
local redis = require "skynet.db.redis"
require "skynet.manager"

local constant = require "constant"
local NET_EVENT = constant.NET_EVENT
local NET_RESULT = constant.NET_RESULT

local CMD = {}
local SOCKET = {}
local GATE_SERVICE

local SECRET_STATE = {
    WAIT_CLIENT_KEY = 1,
    CONFIRM_SUCCESS = 2,
}

local AGENT_MAP = {}
local USER_MAP = {}

local CENTER_REDIS

local AGENT_POOL = {}

local agent_manager = {}
local function disconnect_fd(fd)
    local agent_item = AGENT_MAP[fd]
    AGENT_MAP[fd] = nil
    skynet.call(GATE_SERVICE,"lua","kick",fd)
    if agent_item then
        if agent_item.user_id then
            USER_MAP[agent_item.user_id] = nil
        end
        if agent_item.service_id then
            skynet.call(agent_item.service_id, "lua", "disconnect")
            skynet.send(agent_item.service_id, "lua", "free")
            table.insert(AGENT_POOL, agent_item.service_id)
        end
    end

end

local function generate_standby_agents()
    for i=1,10 do
        table.insert(AGENT_POOL, skynet.newservice("agent"))
    end
end

local function generate_new_agent()
    local agent = skynet.newservice("agent")
    table.insert(AGENT_POOL, agent)
end

local function allock_agent()
    --取出一个没有用到的service 进行绑定
    local unused_agent = table.remove(AGENT_POOL, 1)
    if not unused_agent then
        unused_agent = generate_new_agent()
    end
    return unused_agent
end

local function send(fd, data_content, secret)
    local data, err = pbc.encode("S2C", data_content)
    if err then
        log.errorf("encode protobuf error: %s", err)
        return
    end

    if data then
        if secret then
            local success, e = pcall(crypt.desencode, secret, data)
            if success then
                data = e
            else
                log.error("desencode error")
                return
            end
        end

        socket.write(fd, string.pack(">s2", crypt.base64encode(data)))
    end
end

function SOCKET.close(fd)
    log.info("socket close",fd)
    disconnect_fd(fd)
end

function SOCKET.error(fd, msg)
    log.info("socket error",fd, msg)
    disconnect_fd(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    log.info("socket warning", fd, size)
end

--建立连接
function SOCKET.open(fd, addr)
    local agent_item = {}
    agent_item.fd = fd
    agent_item.state = SECRET_STATE.WAIT_CLIENT_KEY
    agent_item.challenge = crypt.randomkey()
    agent_item.serverkey = crypt.randomkey()

    local req_msg = {}
    req_msg["v1"] = crypt.base64encode(agent_item.challenge)
    req_msg["v2"] = crypt.base64encode(crypt.dhexchange(agent_item.serverkey))

    --连接建立之后 首先要交换密钥 向客户端发送密钥
    send(fd, {[NET_EVENT.HANDSHAKE] = req_msg})

    AGENT_MAP[fd] = agent_item
end

function SOCKET.data(fd, data)
    local agent_item = AGENT_MAP[fd]
    if not agent_item then
        --如果AGENT_MAP中没有该fd,但是又走到了这里,说明出了错误
        log.info("agent map has not this fd ",fd)
        disconnect_fd(fd)
        return
    end
    --对数据进行base64解密
    data = crypt.base64decode(data)

    --如果密钥交换完毕的话  还需要一步解密操作
    local secret = agent_item.secret
    if secret then
        data = crypt.desdecode(secret, data)
    end

    --解析protobuf 获取数据内容
    local data_content, err = pbc.decode("C2S", data)
    if err or not data_content then
        log.errorf("decode protobuf error: %s", data)
    end
    --如果状态等于WAIT_CLIENT_KEY 说明密钥交换还没完毕
    if agent_item.state == SECRET_STATE.WAIT_CLIENT_KEY then
        if rawget(data_content, NET_EVENT.HANDSHAKE) then
            local req_msg = data_content[NET_EVENT.HANDSHAKE]
            local clientkey = crypt.base64decode(req_msg["v1"])
            --客户端的key 和 服务端本地存储的key 生成最终的密钥key
            local secret = crypt.dhsecret(clientkey, agent_item.serverkey)
            --使用hmac64 解密客户端发来的密钥 跟 服务端生成的密钥是否一样，如果一样则说明密钥交换成功,否则交换失败
            if crypt.base64decode(req_msg["v2"]) == crypt.hmac64(agent_item.challenge, secret) then
                agent_item.clientkey = clientkey
                agent_item.secret = secret
                agent_item.state = SECRET_STATE.CONFIRM_SUCCESS
            else
                --如果密钥交换失败,则断开其连接
                disconnect_fd(fd)
            end
            return
        end
    --如果状态等于CONFIRM_SUCCESS 说明密钥交换完毕 可以进行正常的数据通讯
    elseif agent_item.state == SECRET_STATE.CONFIRM_SUCCESS then
        if rawget(data_content, NET_EVENT.LOGIN) then
            local req_msg = data_content[NET_EVENT.LOGIN]

            local login_type = req_msg.login_type
            local account = req_msg.account
            local token = req_msg.token
            local user_name = req_msg.user_name
            local user_pic = req_msg.user_pic

            local rsp_msg = {}
            
            local login_result = skynet.call(".logind","lua","login",login_type,account,token)

            rsp_msg.result = login_result and NET_RESULT.SUCCESS or NET_RESULT.AUTH_FAIL
            if login_result then
                local user_id = CENTER_REDIS:get(login_type..":"..account)
                if not user_id then

                    local max_id = CENTER_REDIS:incrby("user_id_generator", 1)
                    user_id = string.upper(string.format("%d%07x",1,max_id))
                    CENTER_REDIS:set(login_type..":"..account,user_id)
                end


                local reconnect_token = crypt.base64encode(crypt.randomkey() .. crypt.randomkey())
                CENTER_REDIS:hset("info:"..user_id, "reconnect_token", reconnect_token)

                rsp_msg.reconnect_token = reconnect_token
                rsp_msg.user_id = user_id


                agent_item.user_id = user_id

                if #AGENT_POOL < 10 then
                    generate_standby_agents()
                end

                local fd = agent_item.fd
                local secret = agent_item.secret

                --绑定fd 之前先检查之前的fd是否存在并且断开
                if USER_MAP[user_id] then
                    disconnect_fd(USER_MAP[user_id])
                end
                USER_MAP[user_id] = fd

                --取出一个没有用到的service 进行绑定
                local unused_agent = allock_agent()
                agent_item.service_id = unused_agent

                local data = {fd = fd, secret = secret, user_id = user_id}
                data.user_name = user_name
                data.user_pic = user_pic
                --通知该service重新加载数据
                skynet.call(agent_item.service_id, "lua", "start", data)
            end
            send(fd, { ["session_id"] = data_content.session_id, [NET_EVENT.LOGIN] = rsp_msg }, secret)

        elseif rawget(data_content, NET_EVENT.RECONNECT) then
            local req_msg = data_content[NET_EVENT.RECONNECT]

            local user_id = req_msg.user_id
            local token = req_msg.token

            local rsp_msg = {}
            rsp_msg.result = NET_RESULT.FAIL

            if CENTER_REDIS:hget("info:"..user_id, "reconnect_token") == token then
                local reconnect_token = crypt.base64encode(crypt.randomkey() .. crypt.randomkey())
                CENTER_REDIS:hset("info:"..user_id, "reconnect_token", reconnect_token)
                rsp_msg.result = NET_RESULT.SUCCESS
                rsp_msg.reconnect_token = reconnect_token
            end

            send(fd, { ["session_id"] = data_content.session_id, [NET_EVENT.RECONNECT] = rsp_msg }, secret)
        elseif rawget(data_content, NET_EVENT.LOGOUT) then 
            local rsp_msg = {}
            rsp_msg.result = NET_RESULT.SUCCESS
            send(fd, { ["session_id"] = data_content.session_id, [NET_EVENT.LOGOUT] = rsp_msg }, secret)
        elseif agent_item.service_id then
            skynet.send(agent_item.service_id, "lua", "request", data_content)
        else
            log.errorf("wrong connect, state: %s", agent_item.state)
        end
    end



end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    --注册protobuf协议
    pbc.register_file(skynet.getenv("protobuf"))

    -- 启动gate服务 监听来自客户端的连接
    GATE_SERVICE = skynet.newservice("gate")
    skynet.call(GATE_SERVICE, "lua", "open" , {
        port = 8888,
        nodelay = true,
    })

    local redis_manager = require "redis_manager"
    CENTER_REDIS = redis_manager:connectCenterRedis()

    skynet.register ".agent_manager"
end)

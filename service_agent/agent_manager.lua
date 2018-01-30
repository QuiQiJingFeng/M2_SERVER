local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local pbc = require "protobuf"
local redis = require "skynet.db.redis"
local cjson = require "cjson"
require "skynet.manager"

local mysql = require "skynet.db.mysql"
local md5 = require "md5"
local account_db

local CMD = {}
local SOCKET = {}
local self_info = {}

local standby_agent_list = {}
local agent_map = {}
local check_map = {}
local user_map = {}

local SECRET_STATE = {
    WAIT_CLIENT_KEY = 1,
    CONFIRM_SUCCESS = 2,
}

local function generate_standby_agents()
    for i=1,10 do
        table.insert(standby_agent_list, skynet.newservice("agent"))
    end
end

local function free_agent(fd)
    if fd then
        local agent_item = agent_map[fd]
        agent_map[fd] = nil
        check_map[fd] = nil
        skynet.call(self_info.gate, "lua", "kick", fd)
        if agent_item then
            if agent_item.user_id then
                user_map[agent_item.user_id] = nil
            end
            if agent_item.service_id then
                skynet.send(agent_item.service_id, "lua", "free")
                table.insert(standby_agent_list, agent_item.service_id)
            end
        end
    end
end

local function set_agent(agent_item, user_id, is_reconnect)
    agent_item.user_id = user_id

    if #standby_agent_list < 10 then
        generate_standby_agents()
    end

    local fd = agent_item.fd
    local secret = agent_item.secret

    free_agent(user_map[user_id])
    user_map[user_id] = fd

    check_map[fd] = nil


    agent_item.service_id = table.remove(standby_agent_list, 1)
    skynet.call(agent_item.service_id, "lua", "start", {fd = fd, secret = secret, user_id = user_id}, is_reconnect)

    local reconnect_token = crypt.base64encode(crypt.randomkey() .. crypt.randomkey())
    self_info.redis:hset(user_id, "reconnect_token", reconnect_token)
    return reconnect_token
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
    free_agent(fd)
end

function SOCKET.error(fd, msg)
    log.info("socket error",fd, msg)
    free_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    log.info("socket warning", fd, size)
end

function SOCKET.open(fd, addr)
    local agent_item = {}
    agent_item.fd = fd
    agent_item.state = SECRET_STATE.WAIT_CLIENT_KEY
    agent_item.challenge = crypt.randomkey()
    agent_item.serverkey = crypt.randomkey()

    local req_msg = {}
    req_msg["v1"] = crypt.base64encode(agent_item.challenge)
    req_msg["v2"] = crypt.base64encode(crypt.dhexchange(agent_item.serverkey))

    send(fd, {["handshake"] = req_msg})

    agent_map[fd] = agent_item
    check_map[fd] = skynet.time()
end

local MAX_USER_ID = 4967000
local CONVERT = { [10] = "A", [11] = "B", [12] = "C", [13] = "D", [14] = "E", [15] = "F", [16] = "G",
[17] = "H", [18] = "I", [19] = "J", [20] = "K", [21] = "L", [22] = "M", [23] = "N", [24] = "O", [25] = "P",
[26] = "Q", [27] = "R", [28] = "S", [29] = "T",[30] = "U", [31] = "V",[32] = "W",[33] = "X", [34] = "Y", [35] = "Z" }

local function CreateUserid()
    local max_id = self_info.redis:incrby("user_id_generator", 1)
    if max_id >= MAX_USER_ID then
        return nil
    end

    local user_id = tonumber(string.format("%d%07d", 1, max_id))
    local unin_id = ""
    local multiple = 0
    while user_id > 0 do
        local dec = user_id%36
        user_id = math.floor(user_id/36)
        dec = CONVERT[dec] or dec
        unin_id = dec .. unin_id
        multiple = multiple + 1
    end
    return unin_id
end

function SOCKET.data(fd, data)
    local agent_item = agent_map[fd]
    if agent_item then
        data = crypt.base64decode(data)

        local secret = agent_item.secret
        if secret then
            data = crypt.desdecode(secret, data)
        end

        local data_content, err = pbc.decode("C2S", data)
        if err then
            log.errorf("decode protobuf error: %s", data)
        end
        if data_content then
            if agent_item.state == SECRET_STATE.WAIT_CLIENT_KEY then
                if rawget(data_content, "handshake") then
                    local req_msg = data_content["handshake"]
                    local clientkey = crypt.base64decode(req_msg["v1"])
                    local secret = crypt.dhsecret(clientkey, agent_item.serverkey)
                    if crypt.base64decode(req_msg["v2"]) == crypt.hmac64(agent_item.challenge, secret) then
                        agent_item.clientkey = clientkey
                        agent_item.secret = secret
                        agent_item.state = SECRET_STATE.CONFIRM_SUCCESS
                        return
                    end
                end
            elseif agent_item.state == SECRET_STATE.CONFIRM_SUCCESS then
                if rawget(data_content, "login") then
                    -- 登录请求，验证不通过时直接断开连接，否则分配agent
                    local req_msg = data_content["login"]

                    local login_type = req_msg.login_type
                    local account = req_msg.account
                    local token = req_msg.token

                    local rsp_msg = {}
                    rsp_msg.result = "fail"
                    if login_type == "debug" then
                        local password = md5.sumhexa(token)
                        local check_str = string.format("select count(*) as count from account_register where name = '%s' and password='%s'",account,password)
                        local ret = account_db:query(check_str) or {}
                        if ret[1].count == 1 then
                            local user_id = CreateUserid()
                            if user_id then
                                self_info.redis:set(account,user_id)
                                local reconnect_token = set_agent(agent_item, user_id, false)
                                rsp_msg.result = "success"
                                rsp_msg.reconnect_token = reconnect_token
                                rsp_msg.user_id = user_id
                            end
                        else
                            -- 验证失败
                            rsp_msg.result = "auth_fail"
                        end
                    else
                        rsp_msg.result = "unknow_login_type"
                    end

                    send(fd, { ["session_id"] = data_content.session_id, ["login"] = rsp_msg }, secret)

                    if rsp_msg.result == "success" then
                        return
                    end
                elseif rawget(data_content, "reconnect") then
                    local req_msg = data_content["reconnect"]

                    local user_id = req_msg.user_id
                    local token = req_msg.token

                    local rsp_msg = {}
                    rsp_msg.result = "fail"

                    if self_info.redis:hget(user_id, "reconnect_token") == token then
                        local reconnect_token = set_agent(agent_item, user_id, true)
                        rsp_msg.result = "success"
                        rsp_msg.reconnect_token = reconnect_token
                    end

                    send(fd, { ["session_id"] = data_content.session_id, ["reconnect"] = rsp_msg }, secret)

                    if rsp_msg.result == "success" then
                        return
                    end
                elseif rawget(data_content, "logout") then
                    local rsp_msg = {}
                    rsp_msg.result = "success"
                    send(fd, { ["session_id"] = data_content.session_id, ["logout"] = rsp_msg }, secret)
                elseif agent_item.service_id then
                    skynet.send(agent_item.service_id, "lua", "request", data_content)
                    return
                else
                    log.errorf("wrong connect, state: %s", agent_item.state)
                end
            end
        end
    end

    free_agent(fd)
end

function CMD.close(fd)
    free_agent(fd)
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

    local redis_address = skynet.getenv("redis_address")
    local address, port = string.match(redis_address, "([%d%.]+):([%d]+)")
    self_info.redis = redis.connect({ host = address, port = port })


    account_mysql_conf = skynet.getenv("account_mysql")
    local host, port = string.match(account_mysql_conf,"([%d%.]+):([%d]+)")
    account_db = mysql.connect({
        host= host,
        port= tonumber(port),
        user="root",
        max_packet_size = 1024 * 1024,
        database="gmtool"
    })

    pbc.register_file(skynet.getenv("protobuf"))

    -- 启动gate服务
    self_info.gate = skynet.newservice("gate")
    skynet.call(self_info.gate, "lua", "open" , {
        port = 8888,
        nodelay = true,
    })

    -- 定时检查未完成握手的连接
    skynet.fork(function()
        while true do
            skynet.sleep(1000)
            local now = skynet.time()
            for fd,time in pairs(check_map) do
                if now - time > 60 then
                    free_agent(fd)
                end
            end
        end
    end)

    skynet.register ".agent_manager"
end)

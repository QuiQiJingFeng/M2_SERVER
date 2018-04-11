local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "skynet.log"
local pbc = require "protobuf"
local redis = require "skynet.db.redis"
require "skynet.manager"
local utils = require "utils"
local constant = require "constant"
local cjson = require "cjson"

local CMD = {}
local SOCKET = {}
local GATE_SERVICE

local SECRET_STATE = {
    WAIT_CLIENT_KEY = 1,
    CONFIRM_SUCCESS = 2,
}

local fd_to_info = {}
local userid_to_info = {}
local roomid_to_agent = {}
local room_services = {}
local REDIS_DB = 0
--获取一个唯一的房间号ID
local function getUnusedRandomId()
    local pre_id = math.random(1,9)
    local last_id = string.format("%05d",math.random(0,99999)) 
    local random_id = tonumber(pre_id..last_id)

    local ret = skynet.call(".redis_center","lua","SISMEMBER",REDIS_DB,"room_pool",random_id)
    if ret == 1 then
        return getUnusedRandomId()
    else
        skynet.call(".redis_center","lua","SADD",REDIS_DB,"room_pool",random_id)
        return random_id
    end
end

local agent_manager = {}

local function send(fd, content, secret)
    local data, err = pbc.encode("S2C", content)
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
    local info = fd_to_info[fd]
    local room_id = info.room_id
    local user_id = info.user_id
    if info and room_id then
        local service_id = roomid_to_agent[info.room_id]
        local data = {user_id=info.user_id,room_id=info.room_id}
        skynet.send(service_id, "lua", "request", "disconnect",data)    
    end

    if user_id then
        userid_to_info[user_id] = nil
    end
    fd_to_info[fd] = nil
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    log.info("socket warning", fd, size)
end

--建立连接
function SOCKET.open(fd, addr)
    local info = {}
    info.fd = fd
    info.state = SECRET_STATE.WAIT_CLIENT_KEY
    info.challenge = crypt.randomkey()
    info.serverkey = crypt.randomkey()
    info.ip = string.match(addr, "([%d.]+):")

    local req_msg = {}
    req_msg["v1"] = crypt.base64encode(info.challenge)
    req_msg["v2"] = crypt.base64encode(crypt.dhexchange(info.serverkey))

    send(fd, {["handshake"] = req_msg})
    fd_to_info[fd] = info
end

function SOCKET.data(fd, data)
    local info = fd_to_info[fd]
    if not info then
        log.error("internal error")
        skynet.call(GATE_SERVICE,"lua","kick",fd)
        return
    end
    data = crypt.base64decode(data)
    local secret = info.secret
    if secret then
        data = crypt.desdecode(secret, data)
    end

    local content, err = pbc.decode("C2S", data)
    if err or not content then
        log.errorf("decode protobuf error: %s", data)
    end

    if info.state == SECRET_STATE.WAIT_CLIENT_KEY then
        if rawget(content, "handshake") then
            local req_msg = content["handshake"]
            local clientkey = crypt.base64decode(req_msg["v1"])
            local secret = crypt.dhsecret(clientkey, info.serverkey)
            if crypt.base64decode(req_msg["v2"]) == crypt.hmac64(info.challenge, secret) then
                info.clientkey = clientkey
                info.secret = secret
                info.state = SECRET_STATE.CONFIRM_SUCCESS
            else
                log.error("key exchange error")
                skynet.call(GATE_SERVICE,"lua","kick",fd)
            end
            return
        end
    elseif info.state == SECRET_STATE.CONFIRM_SUCCESS then
        -- 心跳包直接返回
        if rawget(content,"heartbeat") then
            send(fd, {session_id = content.session_id, heartbeat = {}},secret)
            return
        end

        if rawget(content, "login") then
            local req_msg = content["login"]
            local user_id = req_msg.user_id
            local token = req_msg.token
            local rsp_msg = {result = "success"}
            local check = skynet.call(".mysql_pool","lua","checkLoginToken",user_id,token)
            if check then
                info.user_id = user_id
                local fd = info.fd
                local secret = info.secret

                local origin_info = userid_to_info[user_id]
                if origin_info and origin_info.fd then
                    send(fd,"handle_error",{result="server_error"})
                    send(origin_info.fd, { handle_error = {result="other_player_login"} }, origin_info.secret)
                    skynet.call(GATE_SERVICE,"lua","kick",origin_info.fd)
                end

                userid_to_info[user_id] = info
            else
                rsp_msg.result = "auth_fail"
            end
            send(fd, { ["session_id"] = content.session_id, ["login"] = rsp_msg }, secret)
        elseif rawget(content, "create_room") then 
            local rsp_msg = {}

            local data = skynet.call(".mysql_pool","lua","checkIsInGame",info.user_id)
            if data then
                rsp_msg.result = "current_in_game"
                send(fd, { ["session_id"] = content.session_id, ["create_room"] = rsp_msg }, secret)
                return
            end

            local req_msg = content["create_room"]
            local room_id = getUnusedRandomId()
            local service_id = table.remove(room_services)
            if not service_id then
                service_id = skynet.newservice("room")
            end
            local now = skynet.time()
            local expire_time = now + 30*60
            roomid_to_agent[room_id] = service_id
            info.room_id = room_id
            req_msg.room_id = room_id
            req_msg.fd = info.fd
            req_msg.user_id = info.user_id
            req_msg.secret = info.secret
            req_msg.expire_time = expire_time
            local result = skynet.call(service_id,"lua","create_room",req_msg)
            rsp_msg.result = result
            send(fd, { ["session_id"] = content.session_id, ["create_room"] = rsp_msg }, secret)
        elseif rawget(content,"join_room") then
            local rsp_msg = {}
            local req_name = "join_room"
            local req_msg = content["join_room"]
            local data = skynet.call(".mysql_pool","lua","checkIsInGame",info.user_id)
            if data then
                req_name = "back_room"
            end

            local req_msg = content["join_room"]
            local room_id = req_msg.room_id
            if not roomid_to_agent[room_id] then
                rsp_msg.result = "not_exist_room"
                send(fd, { ["session_id"] = content.session_id, ["join_room"] = rsp_msg }, secret)
                return
            end
            info.room_id = room_id
            req_msg.fd = info.fd
            req_msg.user_id = info.user_id
            req_msg.secret = info.secret
            local service_id = roomid_to_agent[room_id]
            local result = skynet.call(service_id,"lua",req_name,req_msg)
            rsp_msg.result = result
            send(fd, { ["session_id"] = content.session_id, ["join_room"] = rsp_msg }, secret)
            
        elseif info.room_id then
            local rsp_msg = {}
            local req_name,req_content
            for k,v in pairs(content) do
                if k ~= "session_id" then
                    req_name = k
                    req_content = v
                end
            end
            if not roomid_to_agent[info.room_id] then
                rsp_msg.result = "not_exist_room"
                send(fd, { ["session_id"] = content.session_id, [req_name] = rsp_msg }, secret)
                return
            end

            req_content.user_id = info.user_id
            req_content.room_id = info.room_id
            local service_id = roomid_to_agent[info.room_id]
            local result = skynet.call(service_id, "lua", "request", req_name,req_content)
            rsp_msg.result = result
            send(fd, { ["session_id"] = content.session_id, [req_name] = rsp_msg }, secret)

            if req_name == "leave_room" and result == "success" then
                info.room_id = nil
            end
        else
            log.errorf("wrong connect, state: %s", info.state)
        end
    end
end

local genneralUnusedService = function()
    for i=1,10 do
        local service_id = skynet.newservice("room")
        table.insert(room_services,service_id)
    end
end

local recoverRoomList = function() 
    --恢复房间列表
    local server_id = skynet.getenv("server_id")
    local room_list = skynet.call(".mysql_pool","lua","selectRoomListByServerId",server_id)
    for i,info in ipairs(room_list) do
        local service_id = table.remove(room_services)
        if not service_id then
            service_id = skynet.newservice("room")
        end
        roomid_to_agent[info.room_id] = service_id
        skynet.send(service_id,"lua","recover",info)
    end
end

function CMD.distroyRoom(room_id)
    local service_id = roomid_to_agent[room_id]
    if service_id then
        local data = {}
        data.room_id = room_id
        data.state = constant.ROOM_STATE.ROOM_DISTROY
        skynet.send(".mysql_pool","lua","insertTable","room_list",data)

        table.insert(room_services,room_info.service_id)
        roomid_to_agent[room_id] = nil
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)
    recoverRoomList()
    --注册protobuf协议
    pbc.register_file(skynet.getenv("protobuf"))

    -- 启动gate服务 监听来自客户端的连接
    GATE_SERVICE = skynet.newservice("gate")
    skynet.call(GATE_SERVICE, "lua", "open" , {
        port = 8888,
        nodelay = true,
    })
    genneralUnusedService()

    skynet.register ".agent_manager"
end)

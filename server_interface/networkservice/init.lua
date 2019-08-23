local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "skynet.log"
local redis = require "skynet.db.redis"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
require "functions"
 
local CMD = {}
local SOCKET = {}
local gate_service
local db
local connect_list = {}
local server_proto,client_proto
local role_services = {}
function SOCKET.close(fd)

end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    SOCKET.close(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    log.info("socket warning", fd, size)
end

--建立连接
function SOCKET.open(fd, addr)
    local ip = string.match(addr, "(.-):")
    connect_list[fd] = {ip = ip, fd = fd}
end

function SOCKET.data(fd, data)
    if not connect_list[fd] then
        SOCKET.close(fd)
        return
    end
    local type, name, request, response = server:dispatch(data)
    if name == "login" then
        local nickname = request.nickname
        local password = request.password
        local roleId = skynet.call(".authservice",nickname,password)
        connect_list[fd].roleId = roleId

        local node redis:hget("role:"..roleId,"node")
        if not node then
            node = cluster.query("game")
        end 
        connect_list[fd].node = node
        skynet.call(connect_list[fd].node,"start",connect_list[fd])
        return
    end

    skynet.call(connect_list[fd].node,name,request)

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

    -- 启动gate服务 监听来自客户端的连接
    gate_service = skynet.newservice("gate")
    skynet.call(gate_service, "lua", "open" , {
        port = tonumber(skynet.getenv("port")),
        nodelay = true,
    })

    local addr, port = string.match(skynet.getenv("center_redis"), "([%d%.]+):([%d]+)")
    db = redis.connect({host = addr, port = port})

    server_proto = sprotoloader.load(1):host "package"
    client_proto = sprotoloader.load(2):host "package"
end)

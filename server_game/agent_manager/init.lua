local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "skynet.log"
local pbc = require "protobuf"
require "skynet.manager"
 
local CMD = {}
local SOCKET = {}
local gate_service


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

end

function SOCKET.data(fd, data)

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

    --注册protobuf协议
    pbc.register_file(skynet.getenv("protobuf"))

    -- 启动gate服务 监听来自客户端的连接
    gate_service = skynet.newservice("gate")
    skynet.call(gate_service, "lua", "open" , {
        port = tonumber(skynet.getenv("port")),
        nodelay = true,
    })

    skynet.register ".battle"
end)

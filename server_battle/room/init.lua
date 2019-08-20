local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local Room = require "Room"
local pbc = require "protobuf"
local CommandCenter = require "commands.CommandCenter"
local utils = require "utils"
local config_manager
local CMD = {}

local data = {}

function CMD.CreateRoomREQ(content)
    local response = {result = config_manager.error_code.success}
    Room:getInstance():init(content.settings, content.roomId)
    --是否需要在创建的时候即加入房间
    if content.isJoinRoom then
        local roleId   = content.roleId
        local roleName = content.roleName
        local headUrl  = content.headUrl
        local fd       = content.fd

        result = Room:getInstance():joinRoom(roleId, roleName, headUrl, fd)
        if result == config_manager.error_code.success then
            Room:getInstance():noticeRoomPlayerInfo()
        end
        response.result = result
    end
    response.roomId = content.roomId
    return response
end

function CMD.JoinRoomREQ(content)
    local response = {result = config_manager.error_code.success}
    local roleId   = content.roleId
    local roleName = content.roleName
    local headUrl  = content.headUrl
    local fd       = content.fd
    result = Room:getInstance():joinRoom(roleId, roleName, headUrl, fd)
    if result == config_manager.error_code.success then
        Room:getInstance():noticeRoomPlayerInfo()
    end
    response.result = result
    return response
end

function CMD.Disconnect(content)
    local roleId = content.roleId
    Room:getInstance():setDisconnectRoleId(roleId)
end

function CMD.SelectSeatREQ(content)
    local position = content.position
    local roleId   = content.roleId
    Room:getInstance():selectSeat(roleId,position)    
end

function CMD.LeaveRoomREQ(content)
    local roleId = content.roleId
    Room:getInstance():leaveRoom(roleId)
end

function CMD.Request(req_name,req_content)
    if req_name == "PLAY_STEP_REQ" then
        return Room:getInstance():dispatchStepEvent(req_content)
    else
        local func = CMD[req_name]
        return func(req_content)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    pbc.register_file(skynet.getenv("protobuf"))

    config_manager = require("config_manager")
    config_manager:init()
end)

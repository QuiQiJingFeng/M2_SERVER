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

function CMD.StartGame(room_info)

end

function CMD.GameCMD()

end

function CMD.CleanData()

end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    skynet.register ".game"
end)

local skynet = require "skynet"
require "skynet.manager"
local sharedata = require "skynet.sharedata"
local constant = require "constant"
local room_setting = require "room_setting"
local error_code = require "error_code"
local FUNCTION = {}

--刷新常量配置表
FUNCTION["REFRESH_CONSTANT"] = function()
    sharedata.update("constant",constant)
    sharedata.update("room_setting",room_setting)
    sharedata.update("error_code",error_code)
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

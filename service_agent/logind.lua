local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.login(login_type,account,token)
    return true
end

function CMD.testPrint(str)
    print("调用了testPrint",str)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        if session > 0 then
            skynet.ret(skynet.pack(f(...)))
        else
            f(...)
        end
    end)

    skynet.register ".logind"
end)


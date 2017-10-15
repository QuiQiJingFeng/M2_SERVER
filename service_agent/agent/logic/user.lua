local skynet = require "skynet"

local event_handler = require "event_handler"

local user = {}

function user.init()
    event_handler:on("test", user.test)
end

function user.test(req_msg)
    return "test", {value = req_msg.value}
end

return user
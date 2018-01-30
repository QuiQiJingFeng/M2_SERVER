local skynet = require "skynet"

local event_handler = require "event_handler"

local user = {}

function user.init()
    event_handler:on("query_info", user.QueryInfoReq)
end

function user.QueryInfoReq(req_msg)
    return "query_info", {gold_num = 100}
end

return user
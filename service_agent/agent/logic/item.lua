local skynet = require "skynet"

local event_handler = require "event_handler"

local item = {}

function item.init()
    event_handler:on("create_item", item.create_item)
end

function item.create_item(req_msg)
    return "test", {value = req_msg.value}
end

return item
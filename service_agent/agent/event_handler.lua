local event_handler = {}

local handler_map = {}

function event_handler:on(event_name, callback)
    handler_map[event_name] = callback
end

function event_handler:off(event_name)
    handler_map[event_name] = nil
end

function event_handler:emit(event_name, ...)
    local callback = handler_map[event_name]
    if callback then
        return callback(...)
    end
end

return event_handler
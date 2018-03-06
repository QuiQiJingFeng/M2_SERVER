local utils = {}

function utils:handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

return utils
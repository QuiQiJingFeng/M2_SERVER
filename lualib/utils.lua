local utils = {}

local CONVERT = { [10] = "A", [11] = "B", [12] = "C", [13] = "D", [14] = "E", [15] = "F", [16] = "G",
[17] = "H", [18] = "I", [19] = "J", [20] = "K", [21] = "L", [22] = "M", [23] = "N", [24] = "O", [25] = "P",
[26] = "Q", [27] = "R", [28] = "S", [29] = "T",[30] = "U", [31] = "V",[32] = "W",[33] = "X", [34] = "Y", [35] = "Z" }

function utils:createUserid(max_id)
    local user_id = tonumber(string.format("%d%07d", 11, max_id))
    local unin_id = ""
    local multiple = 0
    while user_id > 0 do
        local dec = user_id%36
        user_id = math.floor(user_id/36)
        dec = CONVERT[dec] or dec
        unin_id = dec .. unin_id
        multiple = multiple + 1
    end
    return unin_id
end

function utils:handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

return utils
local utils = {}

function utils:mergeNewTable(tb1,tb2)
    tb1 = tb1 or {}
    tb2 = tb2 or {}
    local tb = {}
    for k,v in pairs(tb1) do
        tb[k] = v
    end
    for k,v in pairs(tb2) do
        tb[k] = v
    end
    return tb
end

function utils:mergeToTable(tb1,tb2)
    if not tb1 then
        return
    end
    tb2 = tb2 or {}
    for k,v in pairs(tb2) do
        tb1[k] = v
    end
end

function utils:clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local newObject = {}
        lookup_table[object] = newObject
        for key, value in pairs(object) do
            newObject[_copy(key)] = _copy(value)
        end
        return newObject
    end
    return _copy(object)
end


return utils
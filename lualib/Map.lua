local skynet = require "skynet"
local utils = require "utils"
local cjson = require "cjson"

local Map = {}

local function loadFromKey(temp)
    local data = {}
    for i=1,#temp,2 do
        local key = temp[i]
        local value = temp[i+1]
        data[key] = value
    end

    return data
end

function Map.new(db_index,hash_key)

    local temp = skynet.call(".redis_center","lua","HGETALL",db_index,hash_key)
    local data = loadFromKey(temp)

    local property = {}
    local meta = {}
    local values = {}
    for k,v in pairs(data) do
        local value = string.sub (v,1,-6)
        local format = string.sub(v,-5)
        if format == "__M__" then
            values[k] = cjson.decode(value)
        elseif format == "__F__" then
            values[k] = tonumber(value)
        elseif format == "__B__" then
            values[k] = value == "true" and true or false
        elseif format == "__S__" then
            values[k] = value
        end
    end

    function property:updateValues(data)
        local args = {}
        for k,v in pairs(data) do
            values[k] = v
            local value = v
            if type(value) == "table" then
                value = cjson.encode(value).."__M__"
            elseif type(value) == "boolean" then
                value = (value and "true" or "false") .. "__B__"
            elseif type(value) == "number" then
                value = tostring(value).."__F__"
            elseif type(value) == "string" then
                value = value .. "__S__"
            end
            table.insert(args,k)
            table.insert(args,value)
        end
        if #args > 1 then
            skynet.call(".redis_center","lua","HMSET",db_index,hash_key,table.unpack(args))
        end
    end

    function property:delKey(key)
        values[key] = nil
        skynet.call(".redis_center","lua","HDEL",db_index,hash_key,key)
    end

    function property:getValues()
        return values
    end

    function property:getValuesForKey(...)
        local info = {}
        local args = {...}
        for _,key in ipairs(args) do
            print("KEY   KEYK   ",key)
            info[key] = values[key]
        end
        return info
    end

    function property:reloadFromDb()
        local temp = skynet.call(".redis_center","lua","HGETALL",db_index,hash_key)
        local data = loadFromKey(temp)

        for k,v in pairs(data) do
            local value = string.sub (v,1,-6)
            local format = string.sub(v,-5)
            if format == "__M__" then
                values[k] = cjson.decode(value)
            elseif format == "__F__" then
                values[k] = tonumber(value)
            elseif format == "__B__" then
                values[k] = value == "true" and true or false
            elseif format == "__S__" then
                values[k] = value
            end
        end
    end

    setmetatable(property,meta)
    meta.__index = values
    meta.__newindex = function(table,key,v)
        values[key] = v
        local value = v
        if type(value) == "table" then
            value = cjson.encode(value).."__M__"
        elseif type(value) == "boolean" then
            value = (value and "true" or "false") .. "__B__"
        elseif type(value) == "number" then
            value = tostring(value).."__F__"
        elseif type(value) == "string" then
            value = value .. "__S__"
        end
        skynet.call(".redis_center","lua","HSET",db_index,hash_key,key,value)
    end

    return property
end

return Map

 --[[
    example:
    local herokey = "5YC1U:heros"
    local heros = Map.new(db,herokey,{max_hero=100,test="AK47"})
    print("heros.max_hero = ",heros.max_hero)
    print("heros.test = ",heros.test)
    heros.max_hero = 200
    heros.test = "FHQYDIDX"

    local keys = heros:getAllKeys()
    for i=1,#keys do
        local key = keys[i]
        print(key,heros[key])
    end
]]




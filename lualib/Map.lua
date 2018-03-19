local skynet = require "skynet"
local utils = require "utils"

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

function Map.new(db_index,hash_key,defaults)

    local temp = skynet.call(".redis_center","lua","HGETALL",db_index,hash_key)
    local data = loadFromKey(temp)

    local property = {}
    local meta = {}
    local values = utils:mergeNewTable(defaults,data)

    local args = {}
    for k,v in pairs(values) do
        table.insert(args,k)
        table.insert(args,v)
    end
    if #args > 1 then
        skynet.call(".redis_center","lua","HMSET",db_index,hash_key,table.unpack(args))
    end

    function property:updateValues(data)
        utils:mergeToTable(values,data)
        local args = {}
        for k,v in pairs(data) do
            table.insert(args,k)
            table.insert(args,v)
        end
        if #args > 1 then
            skynet.call(".redis_center","lua","HMSET",db_index,hash_key,table.unpack(args))
        end
    end

    function property:delKey(key)
        values[key] = nil
        skynet.call(".redis_center","lua","HDEL",db_index,hash_key,key)
    end

    setmetatable(property,meta)
    meta.__index = values
    meta.__newindex = function(table,key,value)
        values[key] = value
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




local Map = {}

local function loadFromKey(redis,hash_key)
    local data = {}
    local temp = redis:hgetall(hash_key)
    for i=1,#temp,2 do
        local key = temp[i]
        local value = temp[i+1]
        data[key] = value
    end

    return data
end

function Map.new(redis,hash_key,defaults)
    local property = {_redis = redis,_hash_key = hash_key}
    local meta = {}
    local values = {}

    function property:getAllKeys()
        local keys = {}
        for k,v in pairs(values) do
            table.insert(keys,k)
        end
        return keys
    end

    local data = loadFromKey(redis,hash_key)

    defaults = defaults or {} 
    --从redis加载数据
    for k,v in pairs(data) do
        local value = v
        if defaults[k] then
            if type(defaults[k]) == "number" then
                value = tonumber(value)
            end
        end
        values[k] = value
    end

    --取默认数据,默认数据也存入redis
    for k,v in pairs(defaults) do
        if not values[k] then
            values[k] = v
            redis:hset(hash_key,k,v)
        end
    end
    
    setmetatable(property,meta)
    meta.__index = values
    meta.__newindex = function(table,key,value) 
        values[key] = value
        redis:hset(hash_key,key,value)
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




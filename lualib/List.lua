local skynet = require "skynet"
local List = {}

--设置数据 defaults 必须是一个数组
function List.new(db_index,list_key)
    local property = {}
    local values = {}
    local meta = {}

    --指定index插入数据
    function property:insert(pos,value)
        local before = values[pos]
        assert(before,"List insert index out of range")
        table.insert(values,pos,value)
        skynet.call(".redis_center","lua","LINSERT",db_index,list_key,"BEFORE",before,value)
    end

    --往表头插入数据
    function property:insertFront(...)
        local args = {...}
        for i,v in ipairs(args) do
            table.insert(values,1,v)
        end
        skynet.call(".redis_center","lua","LPUSH",db_index,list_key,table.unpack(args))
    end

    --往表尾插入数据
    function property:push(...)
        local args = {...}
        for i,v in ipairs(args) do
            table.insert(values,v)
        end
        skynet.call(".redis_center","lua","RPUSH",db_index,list_key,table.unpack(args))
    end

    --获取列表的长度
    function property:length( )
        return #values
    end

    --指定index 移除数据
    function property:remove(pos)
        assert(pos < #values,"List remove index out of range")
        table.remove(values,pos)
        skynet.call(".redis_center","lua","LREMOVE",db_index,list_key,pos)
    end

    --移除并返回列表的头元素
    function property:removeFrist()
        table.remove(values,1)
        return skynet.call(".redis_center","lua","LPOP",db_index,list_key)
    end

    --移除并返回列表的尾元素。
    function property:removeLast()
        table.remove(values,#values)
        return skynet.call(".redis_center","lua","RPOP",db_index,list_key)
    end

    --清空列表
    function property:clear()
        local length = #values
        value = {}
        meta.__index = values
        skynet.call(".redis_center","lua","LTRIM",db_index,list_key,length,length)
    end

    function property:getValues()
        return values
    end

    --从redis中拿数据填充List
    local data = skynet.call(".redis_center","lua","LRANGE",db_index,list_key,0,-1)
    for index,v in ipairs(data) do
        local value = v
        values[index] = value
    end

    --如果property中查不到就去values里面查
    setmetatable(property,meta)
    meta.__index = values
    --当对property修改数据的时候的处理方法
    meta.__newindex = function(table,index,value)
        assert(index <= #values,"List index out of range")
        values[index] = value
        skynet.call(".redis_center","lua","LSET",db_index,list_key,index-1,value)
    end

    return property
end
 
--[[
    example:
    local listkey = "testList"
    local list = List.new(db,listkey,{"a","b","c","d","e"})
    list[1] = "A"
    list:insert(1,"begin")
    list:push("hello1","hello2")
    list:insertFront("FYD1","FYD2","FYD3")
    list:push(3)
    list:remove(2)
    list:removeLast()
    list:removeFrist()

    local length = list:length()
    for i=1,length do
        print(list[i])
    end
]]


return List


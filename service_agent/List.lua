local List = {}
--list是从0开始索引的,所以这里要做一下处理
local function loadFromKey(redis,list_key)
    return redis:lrange(list_key,0,-1)
end

--设置数据 defaults 必须是一个数组
function List.new(redis,list_key,defaults)
    local property = {_redis = redis,_list_key = list_key}
    local values = {}
    local meta = {}

    --指定index插入数据
    function property:insert(pos,value)
        local before = values[pos]
        assert(before,"List insert index out of range")
        table.insert(values,pos,value)
        self._redis:linsert(self._list_key,'before',before,value)
    end

    --往表头插入数据
    function property:insertFront(...)
        local args = {...}
        for i,v in ipairs(args) do
            table.insert(values,1,v)
        end
        self._redis:lpush(self._list_key,table.unpack(args))
    end

    --往表尾插入数据
    function property:push(...)
        local args = {...}
        for i,v in ipairs(args) do
            table.insert(values,v)
        end
        self._redis:rpush(self._list_key,table.unpack(args))
    end

    --获取列表的长度
    function property:length( )
        return #values
    end

    --指定index 移除数据
    function property:remove(pos)
        assert(pos < #values,"List remove index out of range")
        table.remove(values,pos)
        self._redis:multi()
        self._redis:lset(self._list_key,pos-1,"__deleted__")
        self._redis:lrem(self._list_key,1,"__deleted__")
        local ret = self._redis:exec()
        local errors = ""
        for i, v in ipairs(ret) do
            if not (type(v) == "number" or v == "OK" ) then
                errors = errors .. v
            end
        end
        assert(errors=="","List remove error = "..errors)
    end

    --移除并返回列表的头元素
    function property:removeFrist()
        table.remove(values,1)
        return self._redis:lpop(self._list_key)
    end

    --移除并返回列表的尾元素。
    function property:removeLast()
        table.remove(values,#values)
        return self._redis:rpop(self._list_key)
    end

    --清空列表
    function property:clear()
        local length = #values
        value = {}
        meta.__index = values
        self._redis:ltrim(self._list_key,length,length)
    end

    --从redis中拿数据填充List
    local data = loadFromKey(redis,list_key)    
    for index,v in ipairs(data) do
        local value = v
        values[index] = value
    end

    defaults = defaults or {}
    --取默认数据
    for i=(#values+1),#defaults do
        values[i] = defaults[i]
    end

    --对于列表来说,从redis中拿到的肯定是连续的
    --所以如果默认值列表大于数据列表,则从redis数据索引之后更新redis列表就可以了
    if #defaults > #data then
        local params = {}
        --相差的元素个数
        for i=#data+1,#defaults do
            table.insert(params,values[i]) 
        end
        redis:rpush(list_key,table.unpack(params))
    end

    --如果property中查不到就去values里面查
    setmetatable(property,meta)
    meta.__index = values
    --当对property修改数据的时候的处理方法
    meta.__newindex = function(table,index,value)
        assert(index <= #values,"List index out of range")
        values[index] = value
        redis:lset(list_key,index-1,value)
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


local Util = require("Util")
local ptn = nil

function string.split(input, delimiter)
	local arr = {}
    string.gsub(input, '[^'..delimiter..']+', function(w) table.insert(arr, w) end)
    return arr
end

function io.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

function clone(src)
    if type(src) ~= "table" then
        return src
    else
        local dest = {}
        for k,v in pairs(src) do
            dest[k] = clone(v)
        end
        return dest
    end
end

function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

function table.valueNeed(src,num)
    for k,v in pairs(src) do
        if v >= num then
            return true
        end
    end
end

local MahjongUtil = {}

--format [[1,1,1],[2]]
--返回所有组合
function MahjongUtil:generalGroups(array)
    local result = {}
    local perms = nil
    perms = function(array,group)
        if #array <= 0 then
            return true
        end

        for idx,element in ipairs(array) do
            local dump = clone(array)
            local item = table.remove(dump,idx)
            table.insert(group,item)
            if perms(dump,group) then
                temp = clone(group)
                result[self:toString(temp)] = temp
            end
            table.remove(group)
        end
    end

    perms(array,{})
    return table.values(result)
end

--将组合转换成字符串
function MahjongUtil:toString(array)
    local temp = clone(array)
    for i,element in ipairs(temp) do
        if type(element) == "table" then
            temp[i] = self:toString(element)
        end
    end
    return "{"..table.concat(temp,",") .. "}"
end

function MahjongUtil:tableLink(...)
    local args = {...}
    local result = {}
    for _,element in ipairs(args) do
        for _,value in ipairs(element) do
            table.insert(result,value)
        end
    end
    return result
end

function MahjongUtil:makeArray(num)
    local array = {}
    for i=1,num do
        table.insert(array,0)
    end
    return array
end

function MahjongUtil:ptn(array)
    local groups = self:ptnInter(array)
    local cache = {}
    for i,v in ipairs(groups) do
        local key = self:toString(v)
        cache[key] = v
    end
    return table.values(cache)
end

--组合进行边缘覆盖
function MahjongUtil:ptnInter(array)
    if #array <= 1 then
        return {array}
    end

    local groups = self:generalGroups(array)
    local cache1 = {}
    for i=1,#array do
        for j=i+1,#array do
            local key = self:toString({array[i], 0, array[j]})
            if not cache1[key] then
                cache1[key] = true
                local cache2 = {}
                for k=1,#array[i] + #array[j] + 1 do
                    local t = self:tableLink(self:makeArray(#array[j]),array[i],self:makeArray(#array[j]))

                    for m=1,#array[j] do
                        t[k+m-1] = t[k+m-1] + array[j][m]
                    end
                    table.removebyvalue(t,0,true)
                    for _=1,1 do
                        --没有大于5张的牌类型
                        if table.valueNeed(t,5) then
                            break
                        end
                        --没有连续9张的牌
                        if #t > 9 then
                            break
                        end

                        local key2 = self:toString(t)
                        if not cache2[key2] then
                            cache2[key2] = true
                            local t2 = clone(array)
                            table.remove(t2,i)
                            table.remove(t2,j-1)
                            local array2 = self:tableLink({t},t2)
                            local ret = self:ptnInter(array2)
                            for i,v in ipairs(ret) do
                                table.insert(groups,v)
                            end
                        end
                    end
                end
            end
        end
    end
    return groups
end

--筛选出不相同的组
function MahjongUtil:filterGroups( ... )
   local args = {...}
   local cache = {}
   for index,groups in ipairs(args) do
       for i,group in ipairs(groups) do
           local key = self:toString(group)
           if not cache[key] then
               cache[key] = group
           end
       end
   end

   return table.values(cache)
end

function MahjongUtil:build(  )
    --静态博客有些 现在导致这种容易出问题大括号编译不过去
    local MahjongTab = {
        [2] =  {
                    {{2}}
                },
        [5] =  {
                    {{1,1,1},{2}},
                    {{3},{2}}
                },
        [8] =  {
                    {{1,1,1},{1,1,1},{2}},
                    {{1,1,1},{3},{2}},
                    {{3},{3},{2}}
                },
        [11] = {
                {{1,1,1},{1,1,1},{1,1,1},{2}},
                {{1,1,1},{1,1,1},{3},{2}},
                {{1,1,1},{3},{3},{2}},
                {{3},{3},{3},{2}}
            },
        [14] = {
                {{1,1,1},{1,1,1},{1,1,1},{1,1,1},{2}},
                {{1,1,1},{1,1,1},{1,1,1},{3},{2}},
                {{1,1,1},{1,1,1},{3},{3},{2}},
                {{1,1,1},{3},{3},{3},{2}},
                {{3},{3},{3},{3},{2}},
                {{2},{2},{2},{2},{2},{2},{2}}
                --[[
                    原版算法里面是将七对单独处理的，
                    因为在日本麻将当中,四张相同牌，不被视作七对子,
                    但是国内是算的,所以可以跟14张牌的其他组合一起处理
                    所以国内麻将总的组合数应该是 9716种,而不是9362种
                ]]
            },
    }

    local allGroups = {}
    for idx,config in pairs(MahjongTab) do
        for i,data in ipairs(config) do
            local group = self:ptn(data)
            table.insert(allGroups,group)
        end
    end
    local allCode = {}
    local fgroups = self:filterGroups(table.unpack(allGroups))

    for _,group in ipairs(fgroups) do
        local list = {}
        for idx,item in ipairs(group) do
            if idx ~= 1 then
                table.insert(list,0)
            end
            for i,value in ipairs(item) do
                table.insert(list,value)
            end
        end
        local code = self:encode(list)
        allCode[code] = true
    end

    local file = io.open("codes.lua","wb")
    local contentList = {"local codes = {\n"}
    for code,_ in pairs(allCode) do
        table.insert(contentList,string.format("\t[0X%X] = true,\n",code))
    end
    table.insert(contentList,"}\nreturn codes")
    file:write(table.concat(contentList,"\n"))
    file:close()
    return allCode
end

local CARD_TYPE = {
    [1] = "万", -- 11-19
    [2] = "条", -- 21-29
    [3] = "筒", -- 31-39
    [4] = "风", -- 41-44 东南西北
    [5] = "箭", -- 51-53 中发白
    [6] = "花", -- 61-68 春夏秋冬 梅兰竹菊
}
local CONVERT_MAP = {
    ["1"] = 0,--"0",
    ["2"] = 0x6,--"110", 
    ["3"] = 0x1e,--"11110",
    ["4"] = 0x7e,--"1111110", 
    ["10"] = 0x2,--"10",
    ["20"] = 0xe,--"1110",
    ["30"] = 0x3e,--"111110",
    ["40"] = 0xfe,--"11111110"
}



local CONVERT_MAP2 = {
    ["1"] = "0",
    ["2"] = "110",
    ["3"] = "11110",
    ["4"] = "1111110",
    ["10"] = "10",
    ["20"] = "1110",
    ["30"] = "111110",
    ["40"] = "11111110"
}
--data is table example:{2,0,3,0,3,2}
--将手牌编码到二进制，并转换成10进制数据
function MahjongUtil:encode(data)
    local key = ""
    local code = 0
    local length = 0
    for i=#data,1,-1 do
        local result = nil
        if data[i] == 0 then
            key = "0"
        else
            key = data[i]..key
            result = key
            key = ""
        end
        if result then
            code = code | CONVERT_MAP[result] << length
            length = length + #CONVERT_MAP2[result]
        end
    end
    --[[
        为了避免这种变成相同的,所以给最左边的一位补上1
        1111112
        1112
        2
    ]]
    --给第一位补上1
    code = code | 1 << length
    return code
end
--code is number
function MahjongUtil:decode(code)
    local text = Util:binaryConversion(2,code)
    text = string.sub(text,2)
    text = string.gsub(text,CONVERT_MAP2["40"],"4,X,")
    text = string.gsub(text,CONVERT_MAP2["4"],"4,")
    text = string.gsub(text,CONVERT_MAP2["30"],"3,X,")
    text = string.gsub(text,CONVERT_MAP2["3"],"3,")
    text = string.gsub(text,CONVERT_MAP2["20"],"2,X,")
    text = string.gsub(text,CONVERT_MAP2["2"],"2,")
    text = string.gsub(text,CONVERT_MAP2["10"],"1,X,")
    text = string.gsub(text,CONVERT_MAP2["1"],"1,")
    text = string.gsub(text,"X","0")
    local array =  Util:split(text,",")
    for i,v in ipairs(array) do
        array[i] = tonumber(v)
    end
    return array
end

--生成手牌编码 {21,21,21,12,12}
function MahjongUtil:generalCode(list)
    local reduce = math.floor((#list) % 3)
    if reduce ~= 2 then
        assert(false,"card num error "..reduce)
    end
    local preValue = nil
    local temp = {}
    for _, value in ipairs(list) do
        local type = math.floor(value / 10) + 1
        if preValue == nil then
            table.insert(temp,1)
        elseif type <= 3 and value - preValue == 1 then  --如果是万条筒并且两张牌相邻则补个1
            table.insert(temp,1)
        elseif value == preValue then                    --如果两张牌相等 则数字+1(最高到4)
            temp[#temp] = temp[#temp] + 1
        elseif value ~= preValue then                    --如果两张牌不相等 则补0 并且补1
            table.insert(temp,0)
            table.insert(temp,1)
        end
        preValue = value
    end
    return self:encode(temp)
end

 --生成所有的胡牌组合
 local codes = nil
 if io.exists("codes.lua") then
    codes = require("codes")
 else
    codes = MahjongUtil:build()
 end


local code = MahjongUtil:generalCode({11,11,11,22,22,33,33,33})
print(codes[code])


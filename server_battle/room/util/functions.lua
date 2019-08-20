--[[

Copyright (c) 2011-2014 chukong-inc.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

function printLog(tag, fmt, ...)
    local t = {
        "[",
        string.upper(tostring(tag)),
        "] ",
        string.format(tostring(fmt), ...)
    }
    print(table.concat(t))
end

function printError(fmt, ...)
    printLog("ERR", fmt, ...)
    print(debug.traceback("", 2))
end

function printInfo(fmt, ...)
    if type(DEBUG) ~= "number" or DEBUG < 2 then return end
    printLog("INFO", fmt, ...)
end

local function dump_value_(v)
    if type(v) == "string" then
        v = "\"" .. v .. "\""
    end
    return tostring(v)
end

function dump(value, description, nesting)
    if type(nesting) ~= "number" then nesting = 3 end

    local lookupTable = {}
    local result = {}

    local traceback = string.split(debug.traceback("", 2), "\n")
    print("dump from: " .. string.trim(traceback[3]))

    local function dump_(value, description, indent, nest, keylen)
        description = description or "<var>"
        local spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(dump_value_(description)))
        end
        if type(value) ~= "table" then
            result[#result +1 ] = string.format("%s%s%s = %s", indent, dump_value_(description), spc, dump_value_(value))
        elseif lookupTable[tostring(value)] then
            result[#result +1 ] = string.format("%s%s%s = *REF*", indent, dump_value_(description), spc)
        else
            lookupTable[tostring(value)] = true
            if nest > nesting then
                result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, dump_value_(description))
            else
                result[#result +1 ] = string.format("%s%s = {", indent, dump_value_(description))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = dump_value_(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    dump_(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = string.format("%s}", indent)
            end
        end
    end
    dump_(value, description, "- ", 1)

    for i, line in ipairs(result) do
        print(line)
    end
end

function dumpRelease(...)
    local originPrint = print
    print = release_print
    dump(...)
    print = originPrint
end

function printf(fmt, ...)
    print(string.format(tostring(fmt), ...))
end

function checknumber(value, base)
    return tonumber(value, base) or 0
end

function checkint(value)
    return math.round(checknumber(value))
end

function checkbool(value)
    return (value ~= nil and value ~= false)
end

function checktable(value)
    if type(value) ~= "table" then value = {} end
    return value
end

function isset(hashtable, key)
    local t = type(hashtable)
    return (t == "table" or t == "userdata") and hashtable[key] ~= nil
end

local setmetatableindex_
setmetatableindex_ = function(t, index)
    if type(t) == "userdata" then
        local peer = tolua.getpeer(t)
        if not peer then
            peer = {}
            tolua.setpeer(t, peer)
        end
        setmetatableindex_(peer, index)
    else
        local mt = getmetatable(t)
        if not mt then mt = {} end
        if not mt.__index then
            mt.__index = index
            setmetatable(t, mt)
        elseif mt.__index ~= index then
            setmetatableindex_(mt, index)
        end
    end
end
setmetatableindex = setmetatableindex_

function table.haskey(hashtable,key)
    for k,v in pairs(hashtable) do
        if k == key then
            return true
        end
    end
end

function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif table.haskey(object,"__pacakge") then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local newObject = {}
        lookup_table[object] = newObject
        for key, value in pairs(object) do
            newObject[_copy(key)] = _copy(value)
        end
        return setmetatable(newObject, getmetatable(object))
    end
    return _copy(object)
end

--绑定lua表到Cocostudio中的Node 
function bindLuaObjToNode(node,path,...)
    if tolua.isnull(node) or node.initSuccess then
        return
    end
    local obj = require(path).new()
    setmetatableindex(node,obj)
    node:init(...)
    --只绑定一次
    node.initSuccess = true
end

function class(classname, ...)
    local cls = {__cname = classname}

    local supers = {...}
    for _, super in ipairs(supers) do
        local superType = type(super)
        assert(superType == "nil" or superType == "table" or superType == "function",
            string.format("class() - create class \"%s\" with invalid super class type \"%s\"",
                classname, superType))

        if superType == "function" then
            assert(cls.__create == nil,
                string.format("class() - create class \"%s\" with more than one creating function",
                    classname));
            -- if super is function, set it to __create
            cls.__create = super
        elseif superType == "table" then
            if super[".isclass"] then
                -- super is native class
                assert(cls.__create == nil,
                    string.format("class() - create class \"%s\" with more than one creating function or native class",
                        classname));
                cls.__create = function() return super:create() end
            else
                local obj = {type = "custom"}
                setmetatable(obj,{__index = super})
                -- super is pure lua class
                cls.__supers = cls.__supers or {}
                cls.__supers[#cls.__supers + 1] = obj
                if not cls.super then
                    -- set first super pure lua class as class.super
                    cls.super = obj
                end
            end
        else
            error(string.format("class() - create class \"%s\" with invalid super type",
                        classname), 0)
        end
    end

    cls.__index = cls
    if not cls.__supers or #cls.__supers == 1 then
        setmetatable(cls, {__index = cls.super})
    else
        setmetatable(cls, {__index = function(_, key)
            local supers = cls.__supers
            for i = 1, #supers do
                local super = supers[i]
                if super[key] then return super[key] end
            end
        end})
    end

    if not cls.ctor then
        -- add default constructor
        cls.ctor = function() end
    end
    cls.new = function(...)
        local instance
        if cls.__create then
            instance = cls.__create(...)
        else
            instance = {}
        end
        setmetatableindex(instance, cls)
        instance.class = cls
        instance:ctor(...)
        return instance
    end
    cls.create = function(_, ...)
        return cls.new(...)
    end

    return cls
end

--[[
    代码规范规则:
    1.单行长度不得超过150个字符 选择换行或者修改写法
    2.函数名不为空的，在前五行内要及时注释 
    3.单个函数不得超过50行 统计不包括注释和空格
    4.带下划线的成员变量不允许直接访问
    5.对成员变量的修改只能在成员函数中,不允许直接在外边修改 例如: obj.value = 1 ERROR
    6.成员变量名(包括方法名)必须以小写字母或者下划线开头
    7.不允许使用分号
]]
local MAX_CHAR_LINE = 150  --单行最大长度
local MAX_LINE_NUM = 50    --单个方法长度不能超过50行
local IS_CHECK_NOTE = true --是否检查方法开头的注释
local IS_CHECK_SEMICOLON = true --是否检查分号

--FYD 添加一个包装,规定对类对象的属性赋值,只能在类内部
local function pacakge(target)
    if type(target) == "userdata" then
        local peer = tolua.getpeer(target)
        if not peer then
            peer = {}
        end
        local newpeer = pacakge(peer)
        tolua.setpeer(target,newpeer)
        return target
    else
        local obj = {__stack = {}}
        function obj:push(func)
            table.insert(self.__stack,func)
        end

        function obj:pop()
            table.remove(self.__stack)
        end

        function obj:inFunc()
            local curFunc = self.__stack[#self.__stack]
            local compareFunc = nil
            for i=3,10 do
                local what = debug.getinfo(i).what
                if not string.find(what,"C") then
                    compareFunc = debug.getinfo(i).func
                    break
                end
            end
            return curFunc == compareFunc
        end
        local values = target
        local meta = {}
        setmetatable(obj, meta)
        meta.__index = function(tb,key)
            --下划线开头变量(私有变量) 不允许在外边直接访问,只能通过get方法来访问
            --下滑先开头的方法为私有方法，不可以在类外部调用
            if not (tb:inFunc()) and string.find(key,"_") == 1 then
                error("下划线开头的变量不允许在外部访问")
            end
            --检查变量名的格式 小写字母开头
            if string.lower(string.sub(key,1,1)) ~= string.sub(key,1,1) then
                error("变量名必须以小写字母 或者下划线开头")
            end

            if type(values[key])  == "function" then
                --方法的长度检测
                local info = debug.getinfo(values[key])
                if info.what == "Lua" then
                    local lineNums = info.lastlinedefined - info.linedefined
                    local realNums = lineNums
                    local fileUtils = cc.FileUtils:getInstance()
                    local path = string.sub(info.source,3)
                    local fullPath = fileUtils:fullPathForFilename(path)
                    local lines = {}
                    local index = 1
                    for line in io.lines(fullPath) do
                        table.insert(lines,line)
                        index = index + 1               
                    end
                    --检查方法是否有注释
                    if IS_CHECK_NOTE then
                        local hasNote = false
                        local start = info.linedefined - 5 > 0 and info.linedefined - 5 or 1 
                        for i=start,info.linedefined do
                            local line = lines[i]
                            local tempLine = string.trim(line)
                            if string.sub(tempLine,1,2) == "]]" then
                                hasNote = true
                                break
                            end
                            if string.sub(tempLine,1,2) == "--" then
                                hasNote = true
                                break
                            end
                        end
                        assert(hasNote,"前5行内要及时注释")
                    end
                    
                    --检查方法长度和单行长度以及分号的使用
                    local begin = false
                    for index,line in ipairs(lines) do
                        if index >= info.linedefined and index <= info.lastlinedefined then
                            assert(string.len(line) <= MAX_CHAR_LINE,"单行长度不得超过.."..MAX_CHAR_LINE.."个字符 选择换行或者修改写法")
                            local tempLine = string.trim(line)
                            
                            if tempLine == "" then
                                realNums = realNums - 1
                            end
                            if string.sub(tempLine,1,4) == "--[[" then
                                begin = true
                            end
                            if not begin then
                                if string.sub(tempLine,1,2) == "--" then
                                    realNums = realNums - 1
                                end
                            end
                            if string.sub(tempLine,1,2) == "]]" then
                                begin = false
                            end

                            --检测分号
                            if IS_CHECK_SEMICOLON and string.find(tempLine,";") then
                                error("不允许使用分号")
                            end
                        end
                    end
                    assert(realNums <= MAX_LINE_NUM,"方法的长度不能超过"..MAX_LINE_NUM.."行")
                end

                return function(...)
                    tb:push(values[key])
                    local ret = {values[key](...)}
                    tb:pop()
                    local tableunpack = nil
                    if unpack then
                        tableunpack = unpack
                    else
                        tableunpack = table.unpack
                    end
                    return tableunpack(ret)
                end
            else
                return values[key]
            end
        end
        --只允许在类方法的执行中,使用self.xx赋值成员变量
        --[[
            local obj = class("AA")
            function obj:set(a)
                self.a = a           --OK
            end
            obj:set(222)
            print("obj.a = ",obj.a)  --OK

            obj.a = 111              --ERROR 不允许在类外赋值成员变量
        ]]
        meta.__newindex = function(tb,key,value)
            if type(value) == "function" then
                values[key] = value
            elseif (tb:inFunc()) then 
                values[key] = value
            else
                error("不允许在外部对成员变量赋值")
            end
        end
        return obj
    end
end
--严格模式检测,用法同class
function Class(...)
    local cls = class(...)
    --只在测试环境下对 对象的使用方式做检测
    if device.platform == "windows" or device.platform == "macosx" then
        local origin = cls.new
        cls.new = function(...)
            local instance = origin(...)
            return pacakge(instance)
        end
    end
    return cls
end

local iskindof_
iskindof_ = function(cls, name)
    --因为对每个super都包装了一层,所以这里应该每一个super都拆一层
    if cls.type == "custom" then
        cls = getmetatable(cls)
    end
    local __index = rawget(cls, "__index")
    if type(__index) == "table" and rawget(__index, "__cname") == name then return true end

    if rawget(cls, "__cname") == name then return true end
    local __supers = rawget(__index, "__supers")
    if not __supers then return false end
    for _, super in ipairs(__supers) do
        if iskindof_(super, name) then return true end
    end
    return false
end

function iskindof(obj, classname)
    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then return false end

    local mt
    if t == "userdata" then
        if tolua.iskindof(obj, classname) then return true end
        mt = tolua.getpeer(obj)
    else
        mt = getmetatable(obj)
    end
    if mt then
        return iskindof_(mt, classname)
    end
    return false
end

function import(moduleName, currentModuleName)
    local currentModuleNameParts
    local moduleFullName = moduleName
    local offset = 1

    while true do
        if string.byte(moduleName, offset) ~= 46 then -- .
            moduleFullName = string.sub(moduleName, offset)
            if currentModuleNameParts and #currentModuleNameParts > 0 then
                moduleFullName = table.concat(currentModuleNameParts, ".") .. "." .. moduleFullName
            end
            break
        end
        offset = offset + 1

        if not currentModuleNameParts then
            if not currentModuleName then
                local n,v = debug.getlocal(3, 1)
                currentModuleName = v
            end

            currentModuleNameParts = string.split(currentModuleName, ".")
        end
        table.remove(currentModuleNameParts, #currentModuleNameParts)
    end

    return require(moduleFullName)
end

function handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

function handlerFix(obj, method,args)
    return function(...)
        return method(obj,args,...)
    end
end

function isLuaFileExist(path)
    
    if device.platform == "windows" then
        path = string.gsub(path,"%.","/")..".lua"
        return cc.FileUtils:getInstance():isFileExist(path)
    end
    local ok, ret = pcall(function()
        return require(path)
    end)
    if not ok then
        -- release_print("path not found =>",path)
        -- release_print("path not ret =>",ret)
    end
    return ok
end

function math.newrandomseed()
    local ok, socket = pcall(function()
        return require("socket")
    end)

    if ok then
        math.randomseed(socket.gettime() * 1000)
    else
        math.randomseed(os.time())
    end
    math.random()
    math.random()
    math.random()
    math.random()
end

function math.round(value)
    value = checknumber(value)
    return math.floor(value + 0.5)
end

local pi_div_180 = math.pi / 180
function math.angle2radian(angle)
    return angle * pi_div_180
end

function math.radian2angle(radian)
    return radian * 180 / math.pi
end

function io.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

function io.readfile(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

function io.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

function io.pathinfo(path)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end

    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

function io.filesize(path)
    local size = false
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end

function table.asc(k) return function(a,b) return a[k]<b[k] end end
function table.desc(k) return function(a,b) return a[k]>b[k] end end

function table.nums(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function table.insertto(dest, src, begin)
    begin = checkint(begin)
    if begin <= 0 then
        begin = #dest + 1
    end

    local len = #src
    for i = 0, len - 1 do
        dest[i + begin] = src[i + 1]
    end
end

function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
    return false
end

function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then return k end
    end
    return nil
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

function table.map(t, fn)
    for k, v in pairs(t) do
        t[k] = fn(v, k)
    end
end

function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

function table.filter(t, fn)
    for k, v in pairs(t) do
        if not fn(v, k) then t[k] = nil end
    end
end

function table.unique(t, bArray)
    local check = {}
    local n = {}
    local idx = 1
    for k, v in pairs(t) do
        if not check[v] then
            if bArray then
                n[idx] = v
                idx = idx + 1
            else
                n[k] = v
            end
            check[v] = true
        end
    end
    return n
end

function table.asc(k) return function(a,b) return a[k]<b[k] end end
function table.desc(k) return function(a,b) return a[k]>b[k] end end

string._htmlspecialchars_set = {}
string._htmlspecialchars_set["&"] = "&amp;"
string._htmlspecialchars_set["\""] = "&quot;"
string._htmlspecialchars_set["'"] = "&#039;"
string._htmlspecialchars_set["<"] = "&lt;"
string._htmlspecialchars_set[">"] = "&gt;"

function string.htmlspecialchars(input)
    for k, v in pairs(string._htmlspecialchars_set) do
        input = string.gsub(input, k, v)
    end
    return input
end

function string.restorehtmlspecialchars(input)
    for k, v in pairs(string._htmlspecialchars_set) do
        input = string.gsub(input, v, k)
    end
    return input
end

function string.nl2br(input)
    return string.gsub(input, "\n", "<br />")
end

function string.text2html(input)
    input = string.gsub(input, "\t", "    ")
    input = string.htmlspecialchars(input)
    input = string.gsub(input, " ", "&nbsp;")
    input = string.nl2br(input)
    return input
end

function string.split(input, delimiter)
    local arr = {}
    string.gsub(input, '[^'..delimiter..']+', function(w) table.insert(arr, w) end)
    return arr
end

local function chsize(char)
    if not char then
        print("not char")
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
        return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end
--[[
-- ����utf8�ַ����ַ���, �����ַ�����һ���ַ�����
-- ����utf8len("1���") => 3
function string.utf8len(str)
    local len = 0
    local currentIndex = 1
    while currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        len = len +1
    end
    return len
end
]]
-- ��ȡutf8 �ַ���
-- str:            Ҫ��ȡ���ַ���
-- startChar:    ��ʼ�ַ��±�,��1��ʼ
-- numChars:    Ҫ��ȡ���ַ�����
function string.utf8sub(str, startChar, numChars)
    local _startChar = startChar
    local _numChars = numChars
    if nil == _startChar then _startChar = 1 end
    if nil == _numChars then _numChars = string.utf8len(str) end
    local startIndex = 1
    while _startChar > 1 do
        local char = string.byte(str, startIndex)
        startIndex = startIndex + chsize(char)
        _startChar = _startChar - 1
    end
 
    local currentIndex = startIndex
 
    while _numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + chsize(char)
        _numChars = _numChars -1
    end
    return str:sub(startIndex, currentIndex - 1)
end

function string.ltrim(input)
    return string.gsub(input, "^[ \t\n\r]+", "")
end

function string.rtrim(input)
    return string.gsub(input, "[ \t\n\r]+$", "")
end

function string.trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end

function string.ucfirst(input)
    return string.upper(string.sub(input, 1, 1)) .. string.sub(input, 2)
end

local function urlencodechar(char)
    return "%" .. string.format("%02X", string.byte(char))
end
function string.urlencode(input)
    -- convert line endings
    input = string.gsub(tostring(input), "\n", "\r\n")
    -- escape all characters but alphanumeric, '.' and '-'
    input = string.gsub(input, "([^%w%.%- ])", urlencodechar)
    -- convert spaces to "+" symbols
    return string.gsub(input, " ", "+")
end

function string.urldecode(input)
    input = string.gsub (input, "+", " ")
    input = string.gsub (input, "%%(%x%x)", function(h) return string.char(checknumber(h,16)) end)
    input = string.gsub (input, "\r\n", "\n")
    return input
end

function string.utf8len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

function string.formatnumberthousands(num)
    local formatted = tostring(checknumber(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

--比较两个表是否一样
function campaireTable(src,tsc)
    for key, value in pairs(src) do
        if type(value) ~= "table" then
            assert(value == tsc[key],"key=="..key)
        else
            campaire(value,tsc[key])
        end
    end
end
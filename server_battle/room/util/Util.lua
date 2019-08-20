local qrencode = require("qrencode")
local Util = {}

function Util:saveNodeToPng(node, callback, name, size)
	assert(type(node) ~= "userdata")
    -- clone 一下node，防止对之前的node产生影响
    local localNode = node
    local n_visible = localNode:isVisible()
    local n_pos = cc.p(localNode:getPositionX(), localNode:getPositionY())
    localNode:setVisible(true)

    -- 如果储存的图片未定义名字，则设置默认名
    name = name or "saveNodeToPng.png"

    -- 可写路径，截图会存在这里
    local writablePath = cc.FileUtils:getInstance():getWritablePath()
    local filePath = writablePath .. name
    -- 删除之前的
    if cc.FileUtils:getInstance():isFileExist(filePath) then
        cc.FileUtils:getInstance():removeFile(filePath)
    end

    if size == nil then
        size = node:getContentSize() -- 截图的图片大小
    end

    -- 创建renderTexture
    local render = cc.RenderTexture:create(size.width, size.height)
    localNode:setPosition(cc.p(size.width / 2, size.height / 2))
    -- 绘制
    render:begin()
    localNode:visit()
    render:endToLua()
    -- 保存
    render:saveToFile(name, cc.IMAGE_FORMAT_PNG)
    localNode:setVisible(n_visible)
    localNode:setPosition(n_pos)

    -- 返回存好的文件，如果有callback则调用callback，否则返回文件路径
    if type(callback) == "function" then
        -- 执行schedule检查文件，保存好就调用callback，可能会出问题，比如回调里的东西被释放了
        local checkTimer = nil
        checkTimer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function ()
            -- body
            if cc.FileUtils:getInstance():isFileExist(filePath) then
                cc.Director:getInstance():getScheduler():unscheduleScriptEntry(checkTimer)
                callback(filePath)

            end
        end, 0.01, false)
    end
    return filePath
end

function Util:captureScreen(callBack)
	local cb = function(success, file)
        assert(success,file)
        callBack(file)
    end
    -- 分享截图
    cc.utils:captureScreen(cb, "ScreenShotWithLogo.jpg")
end

-- the DJB hash function
function Util:hash(text)
	local hash = 5381
	for n = 1, #text do
		hash = hash + bit.lshift(hash, 5) + string.byte(text, n)
	end
	return bit.band(hash, 0x7FFFFFFF)
end

--绑定lua表到Cocos的Node 
function Util:bindLuaObjToNode(node,path,...)
    if node.initSuccess then
        return
    end
    local obj = require(path).new()
    setmetatableindex(node,obj)
    node:init(...)
    --只绑定一次
    node.initSuccess = true
end

function Util:randomseed()
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

function Util:encodeURL(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

function Util:now()
    return require("socket").gettime();
end

-- 获取格式化后的时间
function Util:time2Date(time)
	local date = os.date("*t", time)
    return date;
end

-- 获取格式化后的时间 格林威治时间 0时区的时间
function Util:time2DateGMT(time)
    local date = os.date("!*t", time)
    return date;
end

--当前时间戳毫秒
function Util:nowMilliseconds()
    return self:now() * 1000
end



-- lua base64简单处理
-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2
-- character table string
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function Util:base64Encode(content)
    return((content:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, - 1 do r = r ..(b % 2 ^ i - b % 2 ^(i - 1) > 0 and '1' or '0') end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if(#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c +(x:sub(i, i) == '1' and 2 ^(6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) ..({'', '==', '='}) [#content % 3 + 1])
end

-- decoding
function Util:base64Decode(content)
    content = string.gsub(content, '[^' .. b .. '=]', '')
    return(content:gsub('.', function(x)
        if(x == '=') then return '' end
        local r, f = '',(b:find(x) - 1)
        for i = 6, 1, - 1 do r = r ..(f % 2 ^ i - f % 2 ^(i - 1) > 0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if(#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c +(x:sub(i, i) == '1' and 2 ^(8 - i) or 0) end
        return string.char(c)
    end))
end

--A~Z 65-90 所以最高支持format为36进制
--10进制转换目标进制
function Util:binaryConversion(format,value)
    assert(format <= 36,"unsupport format too biger")
    local list = {}
    repeat
        local var = value%format
        if var > 9 then
            var = string.char(55+var)
        end
        table.insert(list,1,var)
        value = math.floor(value/format)
    until (value == 0)
    return table.concat(list,"")
end

--生成36进制的玩家ID
function Util:generalUserId(serverId,instanceId)
    local id = tonumber(serverId .. string.format("%07d",intId))
    return self:binaryConversion(36,id)
end

function Util:split(input, delimiter)
    local arr = {}
    string.gsub(input, '[^'..delimiter..']+', function(w) table.insert(arr, w) end)
    return arr
end

function Util:generalQrcode(message,callBack)
    local layer = cc.LayerColor:create(cc.c3b(255,255,255))
    local size = {width=250,height=250}
    local scene = cc.Director:getInstance():getRunningScene()
    scene:addChild(layer)

    local drawNode = cc.DrawNode:create()
    layer:addChild(drawNode)
    local ok, tab_or_message = qrencode.qrcode(message)
    if not ok then
        error("qrencode failed")
    else
        local unit = 5
        local start = cc.p(0,0)
        local len = #tab_or_message
        size.width = len*unit + unit
        size.height = len*unit + unit
        for x,row in ipairs(tab_or_message) do
            for y,value in ipairs(row) do
                if value > 0 then
                    local newX = start.x + x * unit
                    local newY = start.y + y * unit
                    drawNode:drawPoint(cc.p(newX,newY),unit,cc.c4f(0,0,0,1))
                end
            end
        end
    end

    layer:setContentSize(size)
    self:saveNodeToPng(layer,function(path) 
        layer:removeFromParent()
        if callBack then
            callBack(path)
        end
    end)
end


return Util
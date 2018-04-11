local crypt = require "skynet.crypt"
local hmac = crypt.hmac_sha1
local base64encode = crypt.base64encode
local md5 = require "md5"
local httpc = require("http.httpc")
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

function utils:getFileName(path)
    return string.match(path, ".+/([^/]*%.%w+)$")
end

--下载文件
--http://lsjgame.oss-cn-hongkong.aliyuncs.com/HotUpdate/index.html

--上传文件
--example: bucket_name=lsjgame path=HotUpdate/test2.txt content为字符串或者字节流
--host = "lsjgame.oss-cn-hongkong.aliyuncs.com"
function utils:ossRequest(host,bucket_name,path,content)
    local access_key_id = "LTAI7X831y2ygKTf"
    local access_key_secret = "kyhihlZhrneTp856smDukaBEbY2foU"
 
    local method = "PUT"
    --要转换成0时区的时间,而不是本地时间
    local now = os.date("!%a, %d %b %Y %X GMT") 
    --经过base64的md5码
    local md5code = base64encode(md5.sum(content))
    --传输的大小
    local length = #content
    --二进制流方式传输
    local content_type = "application/octet-stream"
    --文件名
    local file_name = self:getFileName(path)
    --校验字符串
    local signature = base64encode(hmac(access_key_secret,
                method .. "\n"
                .. md5code .. "\n"
                ..content_type.."\n" 
                .. now .. "\n"
                ..string.format("/%s/%s",bucket_name,path)
                ))

    local authorization = "OSS " .. access_key_id .. ":" .. signature

    
    local headers = {
                        ["authorization"] = authorization,
                        ["date"] = now,
                        ["content-type"] = content_type,
                        ["content-length"] = length,
                        ["content-disposition"] = file_name,
                        ["content-md5"] = md5code
                    }

    local status ,body = httpc.request(method,host, "/"..path, nil, headers, content,true)
    if tonumber(status) ~= 200 then
        print("error:=>status=",status)
        print("msg=\n",body)
        return false
    end

    print("---------put success-------")

    return true
end


--洗牌  FisherYates洗牌算法
--算法的思想是每次从未选中的数字中随机挑选一个加入排列，时间复杂度为O(n)
function utils:fisherYates(card_list)
    for i = #card_list,1,-1 do
        --在剩余的牌中随机取一张
        local j = math.random(i)
        --交换i和j位置的牌
        local temp = card_list[i]
        card_list[i] = card_list[j]
        card_list[j] = temp
    end
    return card_list
end

return utils
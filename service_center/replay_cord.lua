local skynet = require "skynet"
require "skynet.manager"
local log = require "skynet.log"
local utils = require "utils"
local cjson = require "cjson"
local CMD = {}

local record_msg = {}
--auto_increment_id replay_id
function CMD.insertRecord(replay_id,msg)
    if not record_msg[replay_id] then
        record_msg[replay_id] = {}
    end
    table.insert(record_msg[replay_id],cjson.encode(msg))
end
--example: bucket_name=lsjgame path=HotUpdate/test2.txt content为字符串或者字节流
--host = "lsjgame.oss-cn-hongkong.aliyuncs.com"
--host,bucket_name,path,content
function CMD.saveRecord(game_type,replay_id)
    if not record_msg[replay_id] then
        return
    end
    local msg = record_msg[replay_id]
    record_msg[replay_id] = nil

    print("------------saveRecord------------game_type=",game_type," replay_id = ",replay_id)
    local prefix = "all"
    local content = table.concat(msg,"\n")
    local success = utils:ossRequest("replaycord.oss-cn-hongkong-internal.aliyuncs.com","replaycord",prefix.."/"..replay_id..".txt",content)
    if not success then
        --设置回调 等会继续尝试发送
        print("FYD===发送失败")
    else
        print("FYD---->>发送成功")
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd])
        if not f then
            log.error("ERROR: not command")
            return
        end
        skynet.ret(skynet.pack(f(...)))
    end)

    skynet.register ".replay_cord"
end)
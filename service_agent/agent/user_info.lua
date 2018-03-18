local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local pbc = require "protobuf"
local cluster = require "skynet.cluster"
local redis_manager = require "redis_manager"
local cjson = require "cjson"
local constant = require "constant"
local PUSH_EVENT = constant["PUSH_EVENT"]
local DB_INDEX = 1
local Map = require "Map"
local List = require "List"

local user_info = {}
local property = {}
local room_list = {}
function user_info:init(info)
	self.fd = info.fd
	self.secret = info.secret
    self.user_ip = info.ip
    self.user_info_key = "info:"..info.user_id
    self.session_id = 0
    self.node_name = skynet.getenv("node_name")
    
    property.user_id = info.user_id
    property.user_name = info.user_name
    property.user_pic = info.user_pic
    --初始化金币数量为0
    property.gold_num = 0
    
    property = Map.new(DB_INDEX,self.user_info_key,property)
    --记录玩家已经创建的房间列表
    room_list = List.new(DB_INDEX,self.user_info_key..":".."room_list")

    --登陆成功之后,推送玩家信息
    local data = {}
    data.user_id = info.user_id
    data.user_name = info.user_name
    data.user_pic = info.user_pic
    data.user_ip = info.ip
    data.gold_num = property.gold_num
    data.room_list = room_list:getValues()
    
    self:send({[PUSH_EVENT.PUSH_USER_INFO] = data})
end

function user_info:pushNewRoomCord(room_id)
    room_list:push(room_id)
end

function user_info:clear()
	property = {}
end

--更新用户属性
function user_info:set(key,value)
    property[key] = value
end

--更新数据到redis
function user_info:update()
    property:update()
end

--获取用户属性
function user_info:get(key)
    return property[key]
end

--获取多项属性
function user_info:getValues(...)
    local values = {}
    local args = {...}
    for _,key in ipairs(args) do
        values[key] = self:get(key)
    end
    return values
end

--获取用户当前已经存在的room_id
function user_info:getCurrentRoomId()
    return self:get("room_id")
end

--获取center服的结点
function user_info:getCenterNode()
    local result,center_node = pcall(cluster.call,"common_server", ".cluster_manager", "pickNode", "center_server")
    if not result then
        print("ERROR: can't find center_node")
        return 
    end
    return center_node
end

function user_info:safeClusterCall(node_name,service_name,func,...)
    return xpcall(cluster.call,debug.traceback,node_name,service_name,func,...)
end

function user_info:send(data_content)
    -- 转换为protobuf编码
    local success, data, err = pcall(pbc.encode, "S2C", data_content)
    if not success or err then
        print("encode protobuf error",cjson.encode(data_content))
        return
    end

    -- 根据密钥进行加密
    if data and self.secret then
        success, data = pcall(crypt.desencode, self.secret, data)
        if not success then
            print("desencode error")
            return
        end
    end

    -- 拼接包长后发送
    socket.write(self.fd, string.pack(">s2", crypt.base64encode(data)))
end

function user_info:getTargetNodeByRoomId(room_id)
    local room_db_index = 2
    local center_node = skynet.call(".redis_center","lua","HGET",room_db_index,"room_list",room_id)
    return center_node
end


function user_info:userDisconnect()
    local room_id = self:get("room_id")
    local user_id = self:get("user_id")
    if not room_id then
        return
    end

    local center_node = self:getTargetNodeByRoomId(room_id)
    if not center_node then
        --如果房间已经解散,则清掉玩家身上的房间号
        local db_index = 1
        skynet.call(".redis_center","lua","HDEL",db_index,self.user_info_key,"room_id")
        return
    end

    --通知center服 有玩家掉线
    local data = {room_id = room_id,user_id = user_id}
    local success,result = self:safeClusterCall(center_node,".room_manager","userDisconnect",data)
    if success and result then
        skynet.call(".redis_center","lua","HDEL",db_index,self.user_info_key,"room_id")
    end
end


return user_info
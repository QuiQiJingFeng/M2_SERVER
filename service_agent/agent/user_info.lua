local skynet = require "skynet"
local cluster = require "skynet.cluster"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local pbc = require "protobuf"
local cjson = require "cjson"
local Map = require "Map"
local event_handler = require "event_handler"
local USER_DB = 1
local ROOM_DB = 2
local user_info = {}
local property

local config_manager = require "config_manager"
local PUSH_EVENT
function user_info:init(info)
    PUSH_EVENT = config_manager.constant.PUSH_EVENT

	self.session_id = 0
    self.fd = info.fd
    self.secret = info.secret

    local data = {}
    data.user_ip = info.user_ip
    data.user_id = info.user_id
    data.user_name = info.user_name
    data.user_pic = info.user_pic

    local info_key = "info:"..info.user_id
    property = Map.new(USER_DB,info_key)
    property:updateValues(data)

    if not property.room_ids then
        property.room_ids = {}
    end

    if not property.gold_num then
        property.gold_num = 10000
    end

    local will_remove = {}
    local room_list = {}
    for _,room_id in ipairs(property.room_ids) do
        local info = {}
        local room_key = "room:"..room_id
        local room_info = Map.new(ROOM_DB,room_key)
        if not room_info.room_id then
            table.insert(will_remove,room_id)
        else
            info.room_id = room_id
            info.expire_time = room_info.expire_time
            info.state = room_info.state
            table.insert(room_list,info)
        end
    end

    for _,room_id in ipairs(will_remove) do
        for i,id in ipairs(property.room_ids) do
            if id == room_id then
                table.remove(property.room_ids,i)
                break
            end
        end
    end
    self:set("room_ids",property.room_ids)

    --登陆成功之后,推送玩家信息
    data.gold_num = property.gold_num
    local push_msg = data
    --TODO FYD 玩家创建的房间信息列表,房间的状态,所以在房间信息中应该以用户ID 做为key
    push_msg.room_list = room_list
    --玩家登陆之后，检查下room_id对应的房间是否解散,如果解散则删掉room_id
    -- FYD
    self:send({[PUSH_EVENT.PUSH_USER_INFO] = push_msg})
end

function user_info:checkGoldNum(num)
    local total = tonumber(self:get("gold_num"))
    return total >= num
end

--更新资源数量
function user_info:updateResource(resource_name,num)
    local total = self:get(resource_name)
    if not total then
        return
    end
    total = total + num
    self:set(resource_name,total)
    local send_data = {["update_resource"] = {resource_name=total}}
    self:send(send_data)
end

function user_info:get(key)
    return property[key]
end

function user_info:set(key,value)
    if not value then
        property:delKey(key)
    else
        property[key] = value
    end
end

--获取用户的多种属性
function user_info:getPropertys(...)
	local info = {}
	local args = {...}
	for _,key in ipairs(args) do
		info[key] = property[key]
	end
	return info
end

function user_info:clear()
    property = {}
end

function user_info:disconnect()
    event_handler:emit("leave_room")
end

function user_info:send(data_content)
    -- 转换为protobuf编码
    local success, data, err = pcall(pbc.encode, "S2C", data_content)
    if not success or err then
        print("encode protobuf error",cjson.encode(data_content))
        return
    end

    -- 根据密钥进行加密
    local secret = self.secret
    if data and secret then
        success, data = pcall(crypt.desencode, secret, data)
        if not success then
            print("desencode error")
            return
        end
    end
    -- 拼接包长后发送
    socket.write(self.fd, string.pack(">s2", crypt.base64encode(data)))
end

--获取center服的结点
function user_info:getCenterNode()
    return self:safeClusterCall("common_server", ".cluster_manager", "pickNode", "center_server")
end

function user_info:safeClusterCall(node_name,service_name,func,...)
    return xpcall(cluster.call,debug.traceback,node_name,service_name,func,...)
end

return user_info
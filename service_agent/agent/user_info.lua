local skynet = require "skynet"
local cluster = require "skynet.cluster"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local pbc = require "protobuf"
local cjson = require "cjson"
local Map = require "Map"
local USER_DB = 1
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
    data.gold_num = 100000

    local info_key = "info:"..info.user_id
    property = Map.new(USER_DB,info_key)
    property:updateValues(data)

    --登陆成功之后,推送玩家信息
    local push_msg = data
    --TODO FYD 玩家创建的房间信息列表,房间的状态,所以在房间信息中应该以用户ID 做为key
    push_msg.room_list = {}
    --玩家登陆之后，检查下room_id对应的房间是否解散,如果解散则删掉room_id
    -- FYD
    self:send({[PUSH_EVENT.PUSH_USER_INFO] = push_msg})

    --创建的房间列表
    property.room_ids = {}
end

function user_info:updateGoldNum(num)
    local total = tonumber(self:get("gold_num"))
    if total >= num then
        total = total + num
        self:set("gold_num",total)

        local send_data = {["update_resource"] = {gold_num=gold_num}}
        self:send(send_data)

        return true
    end
    return false
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
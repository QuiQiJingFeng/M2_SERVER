local skynet = require "skynet"
local log = require "skynet.log"
require "skynet.manager"
local constant = require "constant"
local ROOM_STATE = constant.ROOM_STATE
local cjson = require "cjson"
local room = require "room"
local pbc = require "protobuf"

local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local CMD = {}

local player_list = {}

function CMD.create_room(content)
    local ret = skynet.call(".mysql_pool","lua","selectTableAll","user_info","user_id="..content.user_id)
    local info = ret[1]
    if not info then
        log.error("can't get user_info "..content.user_id)
        return "server_error"
    end

    local data = {}
    data.user_id = content.user_id
    data.room_id = content.room_id
    data.game_type = content.room_setting.game_type
    data.round = content.room_setting.round
    data.pay_type = content.room_setting.pay_type
    data.seat_num = content.room_setting.seat_num
    data.is_friend_room = content.room_setting.is_friend_room
    data.is_open_voice = content.room_setting.is_open_voice
    data.is_open_gps = content.room_setting.is_open_gps
    data.other_setting = cjson.encode(content.room_setting.other_setting)
    data.time = "NOW()"
    skynet.send(".mysql_pool","lua","insertTable","create_room",data)
    data.user_id = nil
    data.owner_id = content.user_id
    data.server_id = skynet.getenv("server_id")
    data.expire_time = content.expire_time
    data.state = ROOM_STATE.GAME_PREPARE
    data.over_round = 0
    data.sit_down_num = 0
    data.cur_round = 0
    data.time = nil
    skynet.send(".mysql_pool","lua","insertTable","room_list",data)

    room:init(data)

    info.user_id = content.user_id
    info.fd = content.fd
    info.secret = content.secret

    room:addPlayer(info)
    table.insert(player_list,player)

    room:refreshRoomInfo()

    return "success"
end

-- 服务器宕机之后重新恢复房间
function CMD.recover(room_info)
    room:recover(room_info)
end

--返回房间
function CMD.back_room(content)
    print("FYD---->返回房间")
    local user_id = content.user_id
    local player = room:getPlayerByUserId(user_id)
    if not player then
        return "not_in_room"
    end
    local ret = skynet.call(".mysql_pool","lua","selectTableAll","user_info","user_id="..user_id)
    local info = ret[1]
    if not info then
        log.error("can't get user_info "..user_id)
        return "server_error"
    end
    info.user_id = content.user_id
    info.fd = content.fd
    info.secret = content.secret
    player:update(info)
    player.disconnect = false
    room:userReconnect(player)
    --如果房间是由于宕机恢复过来的,则该局作废重新开始
    if room.recover_state then
        --遍历下房间中剩下的  在线的玩家是否全部都准备了
        local num = 1
        for i,player in ipairs(room.player_list) do
            if player.disconnect then
                return "success"
            end
            if player.is_sit then
                num = num + 1
            end
        end
        if num >= room.seat_num then
            --开始游戏
            room:refreshRoomInfo()
            room:startGame()
            room:updatePlayersToDb()
        end
    else
        room.game:back_room(user_id)
    end
    return "success"
end

function CMD.join_room(content)

    local ret = skynet.call(".mysql_pool","lua","selectTableAll","user_info","user_id="..content.user_id)
    local info = ret[1]
    if not info then
        log.error("can't get user_info "..content.user_id)
        return "server_error"
    end

    local seat_num = room.seat_num
    local player_num = #room.player_list
    if player_num >= seat_num then
        return "no_position"
    end

    info.user_id = content.user_id
    info.fd = content.fd
    info.secret = content.secret

    room:addPlayer(info)

    room:refreshRoomInfo()

    local room_id = room.room_id
    local game_type = room.game_type
    local user_id = content.user_id
    local args = {user_id = user_id,room_id = room_id,game_type=game_type,time="NOW()"}
    skynet.send(".mysql_pool","lua","insertTable","join_room",args)
    return "success"
end

function CMD.sit_down(content)
    local room_id = content.room_id
    local user_id = content.user_id
    local pos = content.pos
    if pos > room.seat_num then
        return "paramater_error"
    end

    if room.over_round == room.round then
        return "round_not_enough"
    end
    local player = room:getPlayerByUserId(user_id)
    --如果已经是准备状态了
    if player.is_sit then
        return "already_sit"
    end

    local obj = room:getPlayerByPos(pos)
    --如果该位置有人(不是自己的话）则不能入座
    if obj and obj.user_id ~= player.user_id then
        return "pos_has_player"
    end

    player.is_sit = true
    room:updatePlayerProperty(user_id,"user_pos",pos)

    --推送
    local sit_list = room:getPlayerInfo("user_id","user_pos","is_sit")
    for i=#sit_list,1,-1 do
        local obj = sit_list[i]
        if not obj.is_sit then
            table.remove(sit_list,i)
        end
        obj.is_sit = nil
    end
    local rsp_msg = {room_id = room_id,sit_list = sit_list}
    room:broadcastAllPlayers("push_sit_down",rsp_msg)

    room.sit_down_num = room.sit_down_num + 1
    print("FYD------room.seat_num ",room.seat_num)
    print("FYD------room.sit_down_num ",room.sit_down_num)
    if room.seat_num == room.sit_down_num then
        room:startGame()
    end

    room:updatePlayersToDb()

    return "success"
end

function CMD.disconnect(content)
    local user_id = content.user_id
    local player = room:getPlayerByUserId(user_id)
    
    if player.is_sit then
        room:userDisconnect(player)
        return
    end
    local result = CMD.leave_room(content)
    if result ~= "success" then
        room:userDisconnect(player)
    end
end
function CMD.leave_room(content)
    local room_id = content.room_id
    local user_id = content.user_id

    if room.state ~= ROOM_STATE.GAME_PREPARE then
        return "current_in_game"
    end

    room:removePlayer(user_id)
    room:refreshRoomInfo()

    local args = {user_id = content.user_id,room_id = room.room_id,time="NOW()"}
    skynet.send(".mysql_pool","lua","insertTable","leave_room",args)
    room:updatePlayersToDb()

    return "success"
end

function CMD.request(req_name,req_content)
    local func = CMD[req_name]
    if not func then
        if room.game then
            local func2 = room.game[req_name]
            if func2 then
                return func2(room.game,req_content)
            end
        end
        return "no_support_command"
    end
    return func(req_content)
end


local function checkExpireRoom()
    local now = skynet.time()
    if room.expire_time and room.expire_time < now then
        room.state = ROOM_STATE.ROOM_DISTROY
        if room.game then
            room.game:clear()
        end
        room.player_list = {}
        skynet.call(".agent_manager","lua","distroyRoom")
    else
        --每隔1分钟检查一下失效的房间
        skynet.timeout(60 * 100, checkExpireRoom)   
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(subcmd, ...)))
    end)

    pbc.register_file(skynet.getenv("protobuf"))

    checkExpireRoom()

    skynet.register ".room"
end)

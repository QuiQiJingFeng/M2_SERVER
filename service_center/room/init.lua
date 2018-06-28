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
    
    --如果房间是由于宕机恢复过来的,则该局作废重新开始
    if room.recover_state and not room.game then
        --遍历下房间中剩下的  在线的玩家是否全部都准备了
        local num = 0
        for i,player in ipairs(room.player_list) do
            if player.is_sit then
                num = num + 1
            end
        end
        if num >= room.seat_num then
            --开始游戏
            room:startGame(true)
            room:updatePlayersToDb()
            
            room:userReconnect(player)
            room.game:back_room(user_id)
        else
            player.disconnect = false
            room:pushAllRoomInfo()
        end
    elseif room.over_round == room.cur_round then
        --如果某局结束,但是还没有开始新的一局
        room:userReconnect(player)
        room:pushAllRoomInfo()
    elseif room.game then
        room:userReconnect(player)
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

    local sit_num = room:getSitNums()
    if room.seat_num == sit_num then
        skynet.timeout(1,function() 
                room:startGame()
            end)
    end

    room:updatePlayersToDb()

    return "success"
end

function CMD.disconnect(content)
    local user_id = content.user_id
    local player = room:getPlayerByUserId(user_id)
    if not player then
        return
    end
    if player.is_sit or room.cur_round >= 1 then
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

    if room.state ~= ROOM_STATE.GAME_PREPARE and room.state ~= ROOM_STATE.ROOM_DISTROY then
        return "current_in_game"
    end

    room:removePlayer(user_id)
    room:refreshRoomInfo()

    local args = {user_id = content.user_id,room_id = room.room_id,time="NOW()"}
    skynet.send(".mysql_pool","lua","insertTable","leave_room",args)
    room:updatePlayersToDb()

    return "success"
end

function CMD.distroy_room(content)
    local user_id = content.user_id
    local room_id = content.room_id
    local owner_id = room.owner_id
    local type = content.type
    --在游戏当中
    if room.game and room.cur_round >= 1 then
        type = constant.DISTORY_TYPE.ALL_AGREE
    else
        --如果不在游戏当中,房主可以直接解散房间
        if user_id == owner_id then
            type = constant.DISTORY_TYPE.OWNER_DISTROY
        else
            type = constant.DISTORY_TYPE.ALL_AGREE
        end
    end

    --如果是房主解散房间
    if type == constant.DISTORY_TYPE.OWNER_DISTROY then
        if room.state ~= constant.ROOM_STATE.GAME_PREPARE or user_id ~= owner_id then
            return "no_permission_distroy"
        else
            room:distroy(constant.DISTORY_TYPE.OWNER_DISTROY)
            return "success"
        end
    end
    --如果是申请解散房间
    if type ==  constant.DISTORY_TYPE.ALL_AGREE then
        room.can_distroy = true
        local players = room.player_list
        room.confirm_map = room.confirm_map or {}
        local confirm_map = room.confirm_map
        for i,obj in ipairs(players) do
            confirm_map[obj.user_id] = nil
        end
        confirm_map[user_id] = true
        
        for i,player in ipairs(players) do
            local distroy_time = math.ceil(skynet.time() + constant["AUTO_CONFIRM"])
            room.distroy_time = distroy_time
            local data = {}
            for user_id,v in pairs(confirm_map) do
                if v then
                    local info = room:getPlayerByUserId(user_id)
                    table.insert(data,info.user_id)
                end
            end
            
            player:send({notice_other_distroy_room={distroy_time = distroy_time,confirm_map=data}})
        end

        --2分钟 如果玩家仍然没有同意,则自动同意
        skynet.timeout(constant["AUTO_CONFIRM"]*100,function() 
                if room.state == ROOM_STATE.ROOM_DISTROY then
                    print("这个房间已经被解散了")
                    --如果这个房间已经被解散了
                    return 
                end
                local can_distroy = room.can_distroy
                if not can_distroy then
                    print("这个房间已经被人拒绝解散了")
                    --如果这个房间已经被人拒绝解散了
                    return 
                end
                --遍历所有没有同意的玩家,让他同意
                local confirm_map = room.confirm_map
                for user_id,confirm in pairs(confirm_map) do
                    if not confirm then
                        CMD.confirm_distroy_room({user_id=user_id,room_id=room_id,confirm=true})
                    end
                end
            end)
        return "success"
    end
    return "paramater_error"
end

function CMD.confirm_distroy_room(content)
    local user_id = content.user_id
    local room_id = content.room_id
    local confirm = content.confirm
    local can_distroy = room.can_distroy
    if not can_distroy then
        --非法的请求
        return "no_support_command"
    end
    local players = room.player_list
    if confirm then
        local confirm_map = room.confirm_map
        confirm_map[user_id] = true
        --当前玩家的数量
        local player_num = 0
        for i,player in ipairs(players) do
            if not player.disconnect then
                player_num = player_num + 1
            end
        end
        local num = 0
        for k,v in pairs(confirm_map) do
            num = num + 1
        end

        --如果所有人都点了确定
        if num == player_num then
            room.can_distroy = nil
            room.distroy_time = nil
            room.confirm_map = {}
            room:distroy(constant.DISTORY_TYPE.ALL_AGREE)
        else
            local data = {}
            for user_id,v in pairs(confirm_map) do
                if v then
                    local info = room:getPlayerByUserId(user_id)
                    table.insert(data,info.user_id)
                end
            end

            room:broadcastAllPlayers("notice_other_distroy_room",{distroy_time = room.distroy_time,confirm_map=data})
        end
    else
        local s_player = room:getPlayerByUserId(user_id)

        --如果有人不同意,则通知其他人 谁不同意
        local players = room.player_list
        for i,player in ipairs(players) do
            player:send({notice_other_refuse={user_id=s_player.user_id,user_pos=s_player.user_pos}})
        end
        room.confirm_map = {}
        room.can_distroy = nil
    end

    return "success"
end

function CMD.send_audio(content)
    local user_id = content.user_id
    local player = room:getPlayerByUserId(user_id)
    room:broadcastAllPlayers("notice_send_audio",{data = content.data,user_pos=player.user_pos})
    return "success"
end

-- 快捷发言             
function CMD.fast_spake_req(content)
    local user_id = content.user_id
    local player = room:getPlayerByUserId(user_id)

    local msg = {fast_index = content.fast_index,user_pos=player.user_pos}
    print("_________________FastSpakeReq", cjson.encode(msg))

    room:broadcastAllPlayers("notice_fast_spake", msg)
    return "success"
end




function CMD.request(req_name,req_content)
    local func = CMD[req_name]
    if not func then
        if room.game then
            local func2 = room.game[req_name]
            if func2 then
                print("REQ->",req_name,cjson.encode(req_content))
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
        room:distroy(constant.DISTORY_TYPE.EXPIRE_TIME)
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

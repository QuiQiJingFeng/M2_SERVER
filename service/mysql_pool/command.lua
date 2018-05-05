local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local log = require "skynet.log"
local mysql = require "skynet.db.mysql"
local utils = require "utils"
local crypt = require "skynet.crypt"
local mysql_list = {}
local MYSQL_INDEX = 1

local command = {}


local function do_query(sql)
    if MYSQL_INDEX > #mysql_list or MYSQL_INDEX <= 0 then
        log.error("!!!INDEX OUT OF SIDE!!!")
    end
    local db = mysql_list[MYSQL_INDEX]
    local ret = db:query(sql) or {}
    if ret.badresult then
        log.errorf("SQL HAS ERROR: SQL IS FLOW:\n\n%s\n\n MESSAGE IS FLOW\n\n%s\n\n",sql,ret.err)
    end

    return ret
end

---------------------------
--将table转化成插入sql语句
---------------------------
local function convertInsertSql(tb_name,data,quote)
    local query = string.format("insert into `%s` ",tb_name)
    local fileds = {}
    local values = {}
    local updates = {}
    for field,value in pairs(data) do
        if type(field) ~= "string" then
            return "filed must be string"
        end
         table.insert(fileds,field)
         local temp_value = value
         if type(value) == 'string' then
            if value ~= "now()" and value ~= "NOW()" then
                if quote then
                    temp_value = mysql.quote_sql_str(temp_value)
                else
                    temp_value = string.format("'%s'",temp_value)                    
                end
            end
         elseif type(value) == "boolean" then
            temp_value = temp_value and 1 or 0
         end

         if value ~= "now()" and value ~= "NOW()" then
            table.insert(updates,string.format("`%s`=VALUES(`%s`)",field,field))
         end
         table.insert(values,temp_value)
    end

    local query = query .."("..table.concat(fileds,",")..") values("..table.concat(values,",")..") ON DUPLICATE KEY UPDATE "..table.concat(updates,",")..";"
    return query
end

function command:updateIndex()
    MYSQL_INDEX = MYSQL_INDEX + 1
    if MYSQL_INDEX > #mysql_list then
        MYSQL_INDEX = 1
    end
end

function command:init()
    local function on_connect(db)
        db:query("set charset utf8");
    end

    local mysql_conf = sharedata.query("mysql_conf")
    local host,port,database = mysql_conf.host,mysql_conf.port,mysql_conf.database
    assert(host,"host is nil")
    assert(port,"port is nil")
    assert(database,"database is nil")

    for i=1,10 do
        local db = mysql.connect({
            host=host,
            port=port,
            user="root",
            max_packet_size = 1024 * 1024,
            database = database,
            on_connect = on_connect
        })
        table.insert(mysql_list,db)
    end
end

function command:insertTable(tb_name,data,is_quote)
     local sql = convertInsertSql(tb_name,data,is_quote)
     return do_query(sql)
end

function command:selectTable(tb_name,...)

end

function command:selectTableAll(tb_name,filter)
    local sql
    if filter then
        sql = 'select * from '..tb_name..' where '..filter..';'
    else
        sql = 'select * from '..tb_name..';'
    end
    return do_query(sql)
end

local function convert(k)
    return (string.gsub(k, ".", function (c)
               return string.format("%02x", string.byte(c))
             end))
end

function command:checkLoginToken(user_id,token)
    local sql = string.format("select (time) from login where `user_id` = %d order by time desc limit 1;",user_id)
    local data = do_query(sql)
    local info = data[1]
    if info then
        local origin_token = convert(crypt.hmac_sha1("FHQYDIDXIL1ZQL",user_id .. info.time))
        if origin_token == token then
            return true
        end
    end
    return false
end

function command:checkIsInGame(user_id)
    -- 因为删除房间是每个小时删除一次,所以这里应该 排除那些待删除的记录

    local time = math.ceil(skynet.time());
    local sql = string.format("select * from room_list where expire_time > %d and player_list like '%%%d%%'",time,user_id)
    local data = do_query(sql)
    return data[1]
end

--查询所有没有被销毁的房间
function command:selectRoomListByServerId(server_id)
    local now = math.floor(tonumber(skynet.time()))
    local sql = string.format("select * from room_list where server_id = %d and expire_time > %d",server_id,now)
    return do_query(sql)
end

-- 查询指定服务器上的销毁超过12个小时的房间并删除(这就意味着 房间号必须通过mysql来生成)
function command:distroyCord(server_id)
    local time = math.ceil(tonumber(skynet.time() - 12 * 60 * 60))
    local sql = string.format("delete from room_list where server_id = %d and expire_time > %d",server_id,time)
    return do_query(sql)
end

function command:updateGoldNum(num,user_id)
    local sql = "update user_info set gold_num = gold_num + %d where user_id = '%s'"
    sql = string.format(sql,num,user_id)
    return do_query(sql)
end
-- 一次查找4个  如果4个都被用了 则继续筛选
--select round(rand()*(max-min)+min); 生成指定范围内的随机数
function command:getRandomRoomId()
    local sql = [[SELECT room_id
    FROM (
      SELECT FLOOR(RAND() * 899999 + 100000) AS room_id 
      UNION
      SELECT FLOOR(RAND() * 899999 + 100000) AS room_id
      UNION
      SELECT FLOOR(RAND() * 899999 + 100000) AS room_id
      UNION
      SELECT FLOOR(RAND() * 899999 + 100000) AS room_id
    ) AS temp
    WHERE `room_id` NOT IN (SELECT room_id FROM room_list)
    LIMIT 1]];
    for i = 1,10 do
        local ret = do_query(sql)
        local info = ret[1]
        if info then
            return info.room_id
        end
    end
end



return command
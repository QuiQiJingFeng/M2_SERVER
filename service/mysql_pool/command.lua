local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local log = require "skynet.log"
local mysql = require "skynet.db.mysql"
local utils = require "utils"
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
    for field,value in pairs(data) do
        if type(field) ~= "string" then
            return "filed must be string"
        end
         table.insert(fileds,field)

         local temp_value = string.gsub(value," ", ""); 
         if type(value) == 'string' then
            if value ~= "now()" and value ~= "NOW()" then
                if quote then
                    temp_value = mysql.quote_sql_str(temp_value)
                else
                    temp_value = string.format("'%s'",temp_value)                    
                end
            end
         end
         table.insert(values,temp_value)
    end

    local query = query .."("..table.concat(fileds,",")..") values("..table.concat(values,",")..");"
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


return command
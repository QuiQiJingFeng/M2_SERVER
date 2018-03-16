local mysql = require "skynet.db.mysql"
local log  =require "skynet.log"

local mysql_list = {}
local MYSQL_NUM = 10

local CMD = {}



skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        local f = CMD[command]
        if f then
        	skynet.ret(skynet.pack(f(...)))
        else
        	log.error("UNKOWN COMMAND :"..command)
        end
    end)

    local conf = sharedata.query("mysql_conf")

    local function on_connect(db)
        dbx:query("create database if not exists lsj_game charset=utf8mb4;use lsj_game;")
    end
    for i=1,MYSQL_NUM do
        local db = mysql.connect({
            host=conf.host,
            port=conf.port,
            user="root",
            max_packet_size = 1024 * 1024,
            on_connect = on_connect
        })
        if not db then
            log.error("failed to connect mysql")
            skynet.abort()
        end
        mysql_list[i] = db
    end
    
    skynet.register(".mysql_center")
end)
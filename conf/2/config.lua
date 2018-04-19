root = "./"
luaservice = root.."service/?.lua;"..root.."service/?/init.lua;"..root.."service_center/?.lua;"..root.."service_center/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua;"..root.."service_center/?.lua"
lua_cpath = root .. "luaclib/?.so"
snax = root.."test/?.lua"
cpath = root.."cservice/?.so"

thread = 8
harbor = 0

logger = "logger"
logservice = "snlua"
logpath = "."

start = "main"

protobuf = root.."proto/protocol.pb"

center_redis = "127.0.0.1:6379"

center_mysql = "127.0.0.1:3306"

server_id = 2
port = 8889
console_port = 9001
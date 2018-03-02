root = "./"
luaservice = root.."service/?.lua;"..root.."service_common/?.lua;"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua;"..root.."service_common/?.lua"
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


mode = "debug"
--cluster
node_type = "common_server"
node_name = "common_server"
node_address = "127.0.0.1:30001"


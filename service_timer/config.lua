root = "./"
luaservice = root.."service/?.lua;"..root.."service_common/?.lua;"..root.."service_timer/?.lua;"..root.."service_timer/?/init.lua"
lualoader = root .. "lualib/loader.lua"
lua_path = root.."lualib/?.lua;"..root.."lualib/?/init.lua;"..root.."service_timer/?.lua"
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
redis_address = "127.0.0.1:6379"

mode = "debug"
--cluster
node_type = "timer"
if mode == "release" then
elseif mode == "debug" then
    include "../service_common/debug_cluster.lua"
    node_name = debug_timer_node_name
    node_address = debug_timer_node_address
end
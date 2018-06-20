root = "./"
mode = "debug"
sroot = root
if mode == "release" then
	sroot = root .. "bin/"
end
luaservice = sroot.."service/?.lua;"..sroot.."service/?/init.lua;"..sroot.."service_center/?.lua;"..sroot.."service_center/?/init.lua"
lualoader = sroot .. "lualib/loader.lua"
lua_path = sroot.."lualib/?.lua;"..sroot.."lualib/?/init.lua;"..sroot.."service_center/?.lua"
lua_cpath = root .. "luaclib/?.so"
snax = sroot.."test/?.lua"
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

server_id = 1
port = 8890
console_port = 9002

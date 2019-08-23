root = "./"
mode = "debug"
sroot = root
if mode == "release" then
	sroot = root .. "bin/"
end
luaservice = sroot.."service/?.lua;"..sroot.."service/?/init.lua;"..sroot.."service_interface/?.lua;"..sroot.."service_interface/?/init.lua"
lualoader = sroot .. "lualib/loader.lua"
lua_path = sroot.."lualib/?.lua;"..sroot.."lualib/?/init.lua;"..sroot.."service_interface/?.lua"
lua_cpath = root .. "luaclib/?.so"
snax = sroot.."test/?.lua"
cpath = root.."cservice/?.so"

thread = 8
harbor = 0

logger = "logger"
logservice = "snlua"
logpath = "."

start = "main"


inter_face_id = 1
port = 8000 + inter_face_id
console_port = 9000 + inter_face_id

center_redis = "127.0.0.1:6379"


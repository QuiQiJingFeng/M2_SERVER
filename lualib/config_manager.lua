local sharedata = require "skynet.sharedata"
local config_manager = {}

function config_manager:init()
	self.constant = sharedata.query("constant")
	self.server_info = sharedata.query("server_info")
	self.redis_conf = sharedata.query("redis_conf")
	self.mysql_conf = sharedata.query("mysql_conf")
	
end

return config_manager
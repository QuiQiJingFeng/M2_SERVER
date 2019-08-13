local sharedata = require "skynet.sharedata"
local config_manager = {}

function config_manager:init()
	self.constant = sharedata.query("constant")
	self.room_setting = sharedata.query("room_setting")
	self.error_code = sharedata.query("error_code")
end

return config_manager
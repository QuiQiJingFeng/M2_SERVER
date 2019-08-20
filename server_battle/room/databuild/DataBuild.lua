local DataBuild = class("DataBuild")

local _instance = nil

function DataBuild:destroy()
	if not _instance then
		return
	end

	_instance:dispose()
end

function DataBuild:getInstance()
	if not _instance then
		_instance = DataBuild.new()
	end

	return _instance
end

return DataBuild
local CommandCenter = class("CommandCenter")

local _instance = nil

function CommandCenter:destroy()
	if not _instance then
		return
	end

	_instance:dispose()
end

function CommandCenter:getInstance()
	if not _instance then
		_instance = CommandCenter.new()
	end

	return _instance
end

function CommandCenter:ctor()
	self._commands = {}
end

function CommandCenter:registCommands(commands)
    for key,command in pairs(commands) do
        self._commands[key] = command
    end
end

-- 取消某个cmd的注册
function CommandCenter:unregistCommand( key )
    self._commands[key] = nil
end

-- 执行cmd
function CommandCenter:executeCommand( key, content )
    local cmd = self._commands[key]
    assert(cmd,"command not fond")
    local instance = cmd.new(content)
    return instance:execute(content)
end


return CommandCenter
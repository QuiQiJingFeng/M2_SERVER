local CommandCenter = require "commands.CommandCenter"
local config_manager = require "config_manager"
local room_setting = config_manager.room_setting
local GAME_PLAY_CODE = room_setting.GAME_PLAY_CODE
local GAME_PLAY_NAME = room_setting.GAME_PLAY_NAME
local Place = require("Place")
local constant = config_manager.constant
local error_code = config_manager.error_code
local PLAY_TYPE = constant.PLAY_TYPE
local pbc = require "protobuf"

local Room = class("Room")

local _instance = nil

function Room:destroy()
	if not _instance then
		return
	end

	_instance:dispose()
end

function Room:getInstance()
	if not _instance then
		_instance = Room.new()
	end

	return _instance
end

function Room:init(settings,roomId)
	self._settings = settings
	self._settingNameMap = self:convertToGameNameMap(settings)

	self._roomId = roomId
	self._places = {}              --玩家的位置
	self._cardPool = {}            --牌库
	self._curRound = 0             --当前的回合
	self._zpos = 0               --庄家的位置
	self._waiteList = {}         --等待操作的玩家列表



	self:registerCommand()
end

function Room:registerCommand()
	--加载玩法的命令
	local gameType = self:getGameType()
	local commonCommands = require("commands.GAME_TYPE_COMMON.config")
	local gameCommands = require("commands."..gameType.."config")
	CommandCenter:getInstance():registCommands(commonCommands)
	CommandCenter:getInstance():registCommands(gameCommands)
end

function Room:setZpos(zpos)
	self._zpos = zpos
end

function Room:getZpos()
	return self._zpos
end

--牌库
function Room:setCardPool(cardPool)
	self._cardPool = cardPool
end

function Room:getCardPool()
	return self._cardPool
end

--设置当前的回合
function Room:setCurRound(round)
	self._curRound = round
end

function Room:getCurRound()
	return self._curRound
end

function Room:upgradeCurRound()
	self._curRound = self._curRound
end

function Room:getRoomId()
	return self._roomId
end

function Room:getPlace(pos)
	for _,place in ipairs(self._places) do
		if pos == place:getPosition() then
			return place
		end
	end
	assert(false)
end

function Room:getPlaceByRoleId(roleId)
	for _,place in ipairs(self._places) do
		if roleId == place:getRoleId() then
			return place
		end
	end
	assert(false)
end

function Room:getAllPlaces()
	return self._places
end

function Room:setDisconnectRoleId(roleId)
	local hasPlace = nil
	for _,place in ipairs(self._places) do
		if place.roleId == roleId then
			hasPlace = true
			place:setConnected(false)
			break
		end
	end
	assert(hasPlace)
end

function Room:leaveRoom(roleId)
	for idx,place in ipairs(self._places) do
		if roleId == place:getRoleId then
			table.remove(self._places,idx)
			break
		end
	end
	self:noticeRoomPlayerInfo()
end

function Room:selectSeat(roleId,position)
	local positions = {}
	for pos=1,#self:getPlayerNum() do
		positions[pos] = true
	end
	local unUsedPosition = {}
	local selectPlace = nil
	for _,place in ipairs(self._places) do
		local pos = place:getPosition()
		unUsedPosition[pos] = nil
		if not place:getRoleId() == roleId then
			selectPlace = place
		end
	end
	if not unUsedPosition[position] then
		return error_code.position_has_player
	end
	unUsedPosition[position] = nil
	selectPlace:setPosition(position)

	if table.nums(unUsedPosition) <= 0 then
		self:GameStart()
	end
	return error_code.success
end

function Room:GameStart()
	--开局
	CommandCenter:getInstance():executeCommand(PLAY_TYPE.COMMAND_PRE_START)
end

function Room:joinRoom(roleId,roleName,headUrl,fd)
	local num = self:getPlayerNum()
	if num <= #self._places then
		return error_code.empty_room
	end
	local oldPlace = nil
	for _,place in ipairs(self._places) do
		if place.roleId == roleId then
			oldPlace = place
			break
		end
	end
	if not oldPlace then
		local place = Place.new()
		place:setRoleId(roleId)
		place:setRoleName(roleName)
		place:setHeadUrl(headUrl)
		place:setFd(fd)
		place:setConnected(true)
		table.insert(self._places,place)
	else
		oldPlace:setRoleName(roleName)
		oldPlace:setHeadUrl(headUrl)
		oldPlace:setFd(fd)
		oldPlace:setConnected(true)
	end

	return error_code.success
end

function Room:noticeRoomPlayerInfo()
	local response = {}
	response.roomId = self._roomId
	response.settings = self._settings
	response.places = {}
	for _,place in ipairs(self._places) do
		local data = {}
		data.roleId = place:getRoleId()
		data.roleName = place:getRoleName()
		data.position = place:getPosition()
		data.headUrl = place:getHeadUrl()
		table.insert(response.places,data)
	end
    local messageSyn = {notice_room_player_info = response}
	-- 转换为protobuf编码
    local success, data, err = pcall(pbc.encode, "S2C", messageSyn)
    if not success or err then
        print("encode protobuf error",cjson.encode(messageSyn))
        return
    end

    for _,place in ipairs(self._places) do
    	local fd = place:getFd()
	    socket.write(fd, string.pack(">s2", crypt.base64encode(data)))
    end
end

function Room:_filterSettingName(filter)
	local settingNames = table.keys(self._settingNameMap)
	for _,name in ipairs(self.settingNames) do
		if string.find(name,filter) then
			return name
		end
	end
	assert(false)
end

--获取房间人数
function Room:getPlayerNum()
	local key = self:_filterSettingName("PLAYER_")
	return room_setting.CONVERT_PLAYER_NUM[key]
end

--获取游戏的类型
function Room:getGameType()
	return self:_filterSettingName("GAME_TYPE_")
end

--获取付费类型
function Room:getPayType()
	return self:_filterSettingName("PAY_BY_")
end

--获取房间的局数
function Room:getRoundCount()
	local key = self:_filterSettingName("ROOM_COUNT_")
	local config = room_setting.CONVERT_ROUND_NUM[key]
	if not config.isCircle then
		return config.num
	end
	--如果是圈数,则转换成局数
	local playerNum = self:getPlayerNum()
	return config.num * playerNum
end

--检测某个规则是否存在
function Room:hasSettingName(settingName)
	return self._settingNameMap[settingName]
end

--将规则码转换为规则名称
function Room:convertToGameNameMap(settings)
	local settingNameMap = {}
	for _,setting in ipairs(settings) do
		settingNameMap[GAME_PLAY_NAME[setting]] = true
	end
	return settingNameMap
end

function Room:dispatchStepEvent(content)
	local playType = content.playType
	local roleId = content.roleId
	--检查当前是否轮到该玩家操作
	if not self._waiteList[playType] or not table.indexof(self._waiteList[playType],roleId) then
		return error_code.faild
	end
	local ok, ret = pcall(function()
		CommandCenter:getInstance():execute(playType,content)
	end
	return ok and error_code.success or error_code.faild
end

function Room:getWaiteList()
	return self._waiteList
end

function Room:clearWaiteList()
	self._waiteList = {}
end

function Room:appendWaiteList(roleId,playType)
	if not self._waiteList[playType] then
		self._waiteList[playType] = {}
	end
	table.insert(self._waiteList[playType],roleId)
end

return Room
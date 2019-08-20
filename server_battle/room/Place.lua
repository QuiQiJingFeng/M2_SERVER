local Place = class("Place")

function Place:ctor()
	self._operateCards = {}  --吃碰杠、补花等特殊操作
	self._outCards = {}      --已经出的牌
	self._handCards = {}     --手牌  哈希表 id -> card
	self._curScore = 0       --当前局积分
	self._totalScore = 0     --总积分
	self._lastCard = nil     --最后一张摸到的牌
	self._position = -1      --玩家的位置
	self._roleId = -1        --玩家的ID
	self._roleName = ""      --玩家名称
	self._headUrl = ""       --玩家的头像地址
	self._fd = -1            --玩家的fd
	self._connected = false  --玩家是否连接
end

function Place:getHandCards()
	return self._handCards
end

function Place:setConnected(connected)
	self._connected = connected
end

function Place:getConnected()
	return self._connected
end

function Place:setFd(fd)
	self._fd = fd
end

function Place:getFd()
	return self._fd
end

function Place:setHeadUrl(headUrl)
	self._headUrl = headUrl
end

function Place:getHeadUrl()
	return self._headUrl
end

function Place:setRoleId(roleId)
	self._roleId = roleId
end

function Place:getRoleId()
	return self._roleId
end

function Place:setPosition(position)
	self._position = position
end

function Place:getPosition()
	return self._position
end

function Place:addHandCard(card)
	self._lastCard = card
	self._handCards[card:getId()] = card
end

function Place:removeHandCardBy(id)
	self._handCards[id] = nil
end

function Place:removeHandCardByValue(value,num)
	for id,card in pairs(self._handCards) do
		if card:getCardValue() == value then
			self._handCards[id] = nil
			num = num - 1
		end

		if num <= 0 then
			break
		end
	end
end

function Place:addOutCard(card)
	table.insert(self._outCards,card)
end

function Place:removeOutCard(id)
	local find = false
	for index,card in ipairs(self._outCards) do
		if card:getId() == id then
			table.remove(self._outCards,index)
			find = true
			break
		end
	end
	assert(find)
end


return Place
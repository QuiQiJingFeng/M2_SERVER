local Card = class("Card")

function Card:ctor(id,value)
	self._id = id
	self._value = value
	self._cornerType = nil
	self._baoTing = nil
end

function Card:setId(id)
	self._id = id
end

function Card:getId()
	return self._id
end

function Card:setCardValue(value)
	self._value = value
end

function Card:getCardValue()
	return self._value
end

function Card:setCornerType(cornerType)
	self._cornerType = cornerType
end

function Card:getCornerType()
	return self._cornerType
end

function Card:setBaoTing(baoTing)
	self._baoTing = baoTing
end

function Card:getBaoTing()
	return self._baoTing
end

return Card
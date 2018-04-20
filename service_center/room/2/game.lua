
local skynet = require "skynet"
-- local Room = require "Room"
local constant = require "constant"
local ALL_CARDS = constant.ALL_CARDS
local RECOVER_GAME_TYPE = constant.RECOVER_GAME_TYPE
local GAME_CMD = constant.GAME_CMD
local NET_RESULT = constant.NET_RESULT
local PLAYER_STATE = constant.PLAYER_STATE
local ZJ_MODE = constant.ZJ_MODE
local PUSH_EVENT = constant.PUSH_EVENT
local GANG_TYPE = constant.GANG_TYPE
local GAME_OVER_TYPE = constant.GAME_OVER_TYPE
local cjson = require "cjson"
local Judgecard = require("2.judgeCard")

local game = {}
local game_meta = {}
setmetatable(game,game_meta)
game.__index = game_meta
game.__newindex = game_meta

function game:clear()
	local game_meta = {}
	setmetatable(game,game_meta)
	game.__index = game_meta
	game.__newindex = game_meta
end

function game:fisherYates()
	for i = #self.card_list,1,-1 do
		--在剩余的牌中随机取一张
		local j = math.random(i)
		--交换i和j位置的牌
		local temp = self.card_list[i]
		self.card_list[i] = self.card_list[j]
		self.card_list[j] = temp
	end
end

-- 开始游戏
function game:start()
	print("ddz, start()")
	-- 洗牌
	-- self:fisherYates()
	self.other_setting = self.room:get("other_setting")
	--底分
	self.base_score = self.other_setting[1]
	self.iRoomTime = self.other_setting[1]
	self.waite_operators = {}
	-- 发牌，
	self:dealCardServer()
end

function game:dealCardServer( ... )
	print("ddz, start()")
	local players = self.room:get("players")

	-- 每人先发13张牌
	local iHandCards = {}
	for i = 1, 3 do 
		iHandCards[i] = {} 
		for j = 1, 20 do 
			iHandCards[j] = 0
		end
	end

	for i = 1, 3 do 
		for j = 1, 17 do 
			iHandCards[i][j] = self.card_list[(i-1)*17 + j]
			print(string.format("发牌iHandCards[%d][%d] = [%d]", i, j, iHandCards[i][j]))
		end	
		players[i].handle_cards = iHandCards[i]
		self.waite_operators[players[i].user_pos] = "WAIT_DEAL_FINISH"
	end

	-- 

	for i = 54, 52, -1 do 
		table.insert(self.baseCard, self.card_list[i])		
	end

	for index=1,self.room:get("sit_down_num") do
		
		local player = self.room:getPlayerByPos(index)
		local cards = players[index].handle_cards
		local rsp_msg = {}
		rsp_msg.cards = cards
		rsp_msg.user_pos = player.user_pos
		rsp_msg.cur_round = self.room:get("cur_round")

		self.room:sendMsgToPlyaer(player, "deal_card", rsp_msg)
	end
end


function game:init(room_info)

	---------- 公共的，可以直接拷贝----------------
	self.room = Room.rebuild(room_info)
	local game_type = room_info.game_type

	self.card_list = {}
	local game_name = RECOVER_GAME_TYPE[game_type]
	for _,value in ipairs(ALL_CARDS[game_name]) do
		table.insert(self.card_list,value)
	end

	---------- 公共的，可以直接拷贝end----------------

	-- 初始化当前的数据
	self:initGame()

	-- self:start()

end

-- 游戏当前的数据会在这个里面，用self去表示
function game:initGame( ... )
		--洗牌
	self:fisherYates()

	self.other_setting = self.room:get("other_setting")
	--底分
	self.base_score = self.other_setting[1]
	-- 是否是欢乐斗地主
	self.bHuanLe = self.other_setting[2] == 2
	-- 封顶数
	self.iMaxBoom = self.other_setting[3] or 3

	-- 当前操作状态
	self.waite_operators = {}
	--当前出牌的位置
	self.iCurPlayExtraNum = 0
	-- 叫分
	self.iDemandPoint = {0, 0, 0}
	-- 是否叫过分
	self.bDemand = {false, false, false}
	-- 底牌
	self.iBaseCard = {0, 0, 0}	
	-- 当前叫分玩家
	self.iCurDemandPlayer = 0
	-- 当前地主
	self.iLandOwer = 0
	-- 是否加倍
	self.bDoubleTime = {false, false, false}
	-- 地主出了几手牌 用来判断春天
	self.iTurn = 0
	-- 出的牌, 到时候扔进去, 最后填0 
	self.cSendCards = {{}, {}, {}}
	-- 当前出的牌的类型（用于断线重新连接的时候）
	self.cSendNum = {0, 0, 0}
	-- first 
	self.iFirstDemand = 0
	-- 当前桌面上牌权的人 
	self.iTablePlayer = 0
	-- 当前桌子上的牌，　用来判断后面牌的合法性
	self.cTableCard = {} -- 长度20数组

	self.iNowBoom = 0

	-- 当前的底牌
	self.baseCard = {}

	-- 当局的底分
	self.iAmountResult = {0, 0, 0}

	math.randomseed(tostring(os.time()):reverse():sub(1, 6)) 
end

function game:demandPointServer( )
	
	local iRoundIndex = self.room:get("cur_round")
	self.iCurDemandPlayer = math.floor(math.randomseed(100) % 3 )
	-- local data = {user_id = user_id,card = data.card,user_pos = player.user_pos}
	local data = { userExtra = self.iCurDemandPlayer, userNowDemand = self.iMaxPoint};
	--通知所有人 现在 让 玩家叫地主
	self.room:broadcastAllPlayers("SERVER_POINT_DEMAND", data)
end

-- 获取下面三张牌的方法
function game:getBaseCard( ... )
	return self.baseCard
end

-- 客户端叫分通知
game["DEMAND"] = function( self, player, data)

	local pos = player.user_pos
		
	if self.bDemand[pos] == true and self.iFirstDemand ~= pos then
		print(string.format("ERROR, bDemand[%d][%d], iFirstDemand = [%d]", pos,  self.bDemand[pos], self.iFirstDemand))	
		return "IS_DEMAND_POINT"
	end

	self.bDemand[pos] = true

	local bTempDemand = false
	-- 0  不叫
	if data.userDemand == 0 then
		self.iDemandPoint[pos] = 0
		bTempDemand = false
	else -- 欢乐斗地主，只记录一分
		self.iDemandPoint[pos] = data.userDemand  -- 欢乐斗地主只会传1和0
		bTempDemand = true
		if self.iFirstDemand == 0 then
			self.iFirstDemand = pos    -- 记录第一个叫分的人s
		end
	end

	-- 统计下叫分的情况
	local iDemandNums = 0
	-- 看下是否是只有一个人叫了地主
	local iDemandPlayNums = 0
	for i = 1, 3 do 
		if self.iDemandPoint[i] > self.iMaxPoint then
			self.iMaxPoint = self.iDemandPoint[i]
		end

		if self.iDemandPoint[i] > 0 then
			iDemandPlayNums = iDemandPlayNums + 1
		end

		if self.bDemand[i] == true then
			iDemandNums = iDemandNums + 1
		end
	end

	-- 通知玩家叫或者不叫
	self.room:broadcastAllPlayers("SERVER_POINT_DEMAND", data)

	if iDemandNums < 3 and self.iMaxPoint ~= 3 then  -- 经典斗地主， 叫了三分直接就是地主产生
		local next_pos = pos + 1

		if next_pos > self.room:get("seat_num") then
			next_pos = 1
		end
		-- local next_player = self.room:getPlayerByPos(next_pos)

		self.iCurDemandPlayer = next_pos

		local data = { userExtra = self.iCurDemandPlayer, userNowDemand = self.iMaxPoint};
		--通知所有人 现在 让 玩家叫地主
		self.room:broadcastAllPlayers("SERVER_POINT_DEMAND", data)
	else  -- 这个时候就应该是能分出来地主了
		
		-- 3个人都已经叫过分了， 检查下是否只有一个人叫
		if iDemandNums == 3 then
			-- 欢乐斗地主里面特有的
			if self.iFirstDemand == pos then
				if bTempDemand then
					self.iMainPlayer = self.iFirstDemand  -- 这个人就是地主
					self.iCurPlayExtraNum = self.iMainPlayer
										
					local data = {userExtra = self.iMainPlayer, baseCard = {}}
					local baseCard = self:getBaseCard()
					local player = self.room:getPlayerByPos(tempExtra)
					for i, v in pairs(baseCard) do 
						table.insert(player.handle_cards, v)
					end
					data.baseCard = baseCard

					self.room:broadcastAllPlayers("NOTICE_MAIN_PALAYER", data)

					-- -- 通知当前玩家出牌
					self:serverPushPlayCard(self.iCurPlayExtraNum)
					return "success"
				else -- 坑上一个人的玩家， 就去找下上个是谁叫了

					local itemp = pos - 1
					if itemp <= 0 then
						itemp = 3
					end

					local tempExtra = 0
					for i = 1, 2 do 
						if self.iDemandPoint[itemp] > 0 then
							tempExtra = itemp
							break
						end

						itemp = itemp - 1
						if itemp <= 0 then
							itemp = 3
						end
					end

					if tempExtra == 0 then
						print("ERROR::tempExtra = ", tempExtra)
					end

					self.iMainPlayer = tempExtra  -- 这个人就是地主
					self.iCurPlayExtraNum = self.iMainPlayer

					local data = {userExtra = self.iMainPlayer, baseCard = {}}
					local baseCard = self:getBaseCard()
					local player = self.room:getPlayerByPos(tempExtra)
					for i, v in pairs(baseCard) do 
						table.insert(player.handle_cards, v)
					end
					data.baseCard = baseCard
					self.room:broadcastAllPlayers("NOTICE_MAIN_PALAYER", data)
					-- -- 通知当前玩家出牌
					self:serverPushPlayCard(self.iCurPlayExtraNum)
					return "success"
				end
			end
			if iDemandPlayNums == 1 then
				self.iMainPlayer = self.iFirstDemand  -- 这个人就是地主
				self.iCurPlayExtraNum = self.iMainPlayer
				local data = {userExtra = self.iMainPlayer, baseCard = {}}
				local baseCard = self:getBaseCard()

				local player = self.room:getPlayerByPos(tempExtra)
				for i, v in pairs(baseCard) do 
					table.insert(player.handle_cards, v)
				end

				data.baseCard = baseCard
				self.room:broadcastAllPlayers("NOTICE_MAIN_PALAYER", data)

				-- -- 通知当前玩家出牌
				self:serverPushPlayCard(self.iCurPlayExtraNum)
				return "success"
			elseif iDemandPlayNums > 0 then

				-- 欢乐斗地主，继续叫分
				if self.bHuanLe == true then
					local data = { userExtra = self.iFirstDemand, userNowDemand = self.iMaxPoint};
					self.room:broadcastAllPlayers("SERVER_POINT_DEMAND", data)
				else
					-- 谁的分数最大， 谁就是地主
					local iTempPos = 0
					for i = 1, 3 do 
						if self.iDemandPoint[i] == self.iMaxPoint then
							iTempPos = i
							break
						end
					end

					self.iMainPlayer = iTempPos -- 这个人就是地主
					self.iCurPlayExtraNum = self.iMainPlayer
					local data = {userExtra = self.iMainPlayer, baseCard = {}}
					local baseCard = self:getBaseCard()

					local player = self.room:getPlayerByPos(tempExtra)
					for i, v in pairs(baseCard) do 
						table.insert(player.handle_cards, v)
					end

					data.baseCard = baseCard
					self.room:broadcastAllPlayers("NOTICE_MAIN_PALAYER", data)

					-- -- 通知当前玩家出牌
					self:serverPushPlayCard(self.iCurPlayExtraNum)
					return "success"
				end

				-- --通知所有人 现在 让 第一个玩家叫地主
				return "success"
			else
				-- 重新再来一次, 重新洗牌，重新发牌，再重新叫地主
				self:initGame()
				self:start()
			end
		end  
	end

	return "success"
end
	


--通知玩家出牌
function game:serverPushPlayCard(iTableExtraNum)
	local players = self.room:get("players")

	local cardNums = {}
	for i = 1, 3 do 
		-- 统计一下牌数, 
		cardNums[i] = #players[i].handle_cards
	end

	for i,player in ipairs(players) do
		local rsp_msg = {userExtra = iTableExtraNum}
		if player.user_pos == iTableExtraNum then
			rsp_msg.userExtra = self.iCurPlayExtraNum
			rsp_msg.userCard = player.handle_cards
			rsp_msg.userCardNum = cardNums
		end
		self.room:sendMsgToPlyaer(player,"push_play_card",rsp_msg)
	end
end


-- --通知玩家出牌
-- function game:noticePushPlayCard(iTableExtraNum, )
-- 	local players = self.room:get("players")

-- 	local cardNums = {}
-- 	for i = 1, 3 do 
-- 		-- 统计一下牌数, 
-- 		cardNums[i] = #players[i].card_list
-- 	end

-- 	for i,player in ipairs(players) do
-- 		local rsp_msg = {userExtra = iTableExtraNum}
-- 		if player.user_pos == iTableExtraNum then
-- 			-- rsp_msg.card_list = player.card_list
-- 			-- -- rsp_msg.card_stack = player.card_stack
-- 			rsp_msg.userExtra = self.iCurPlayExtraNum
-- 			rsp_msg.userCard = player.card_list
-- 			rsp_msg.userCardNum = cardNums
-- 		end
-- 		self.room:sendMsgToPlyaer(player,"push_play_card",rsp_msg)
-- 	end
-- end

--发牌完毕
game["DEAL_FINISH"] = function(self,player)

	local user_pos = player.user_pos
	if self.waite_operators[user_pos] ~= "WAIT_DEAL_FINISH" then
		return "invaild_operator"
	end
	self.waite_operators[user_pos] = nil
	--计算剩余的数量
	local num = 3
	for k,v in pairs(self.waite_operators) do
		num = num - 1
	end

	if num == 1 then
		--庄家出牌
		-- local zplayer = self.room:getPlayerByPos(self.zpos)
		-- self:drawCard(zplayer)




	end
	return "success"
end



function game:handlingError(...)
	print("-------------------handlingError---------------------", ...)
end


--出牌
game["PLAY_CARD"] = function(self,player,data)
	-- if self.waite_operators[player.user_pos] ~= "WAIT_PLAY_CARD" then
	-- 	return "invaild_operator"
	-- end

	if self.iCurPlayExtraNum ~= player.user_pos then
		print ("非法的出牌, 不是当前玩家出牌")
		return "invaild_operator"
	end

	if not data.card then
		return "paramater_error"
	end

	-- 检测手牌
	local nodePlayer = player
	local iTableNumExtra = player.user_pos

	local cCards = data.cardList
	local iCardType = data.nowType
	local iCardValue = data.nowValue
	local iCardNum = data.cardNums


	if #cCards ~= iCardNum then
		print(string.format("ERROR::card = [%d],iCardNum = [%d] ", #cCards, iCardNum))
	end

	-- 这手牌是否为Pass
	local isPass = false

	if iCardNum == 0 then
		isPass = true
	end


	-- 判断下是否是当前的牌权，如果是当前的牌权， 就直接干掉
	if self.iTablePlayer == iTableNumExtra then
		print(string.format("ERROR::cCards = [%d],iCardNum = [%d] ", #cCards, iCardNum))
	end

	local cCardTemp = player.handle_cards

	local iOldType;
	local iOldValue;
	local iNowType;
	local iNowValue;

	if bIsPass == false then
		if iTableNumExtra == self.iMainPlayer then
			self.iTurn = self.iTurn + 1
		end

		-- 在这里判断扑克牌的存在合法性（如果不是Pass，才需要判断）
		for i = 1, 20 do 
			if not cCards[i] then
				break
			end

			local bFind = false
			for j = 1, 20 do 
				if cCardTemp[j] == 0 or cCardTemp[j] == nil then
					break
				end	
				if cCardTemp[j] == cCards[i] then
					bFind = true
					cCardTemp[j] = 0
				end
			end

			if bFind == false then
				local error_msg = string.format("没有找到这张牌[%d][%d]", i, cCards[i])
				self:handlingError(error_msg)

				return "error"
			end
		end

		local temp = {}
		local iCardsCount = 0

		for i = 1, 20 do 
			if cCards[i] then
				temp[i] = math.floor(cCards[i] % 100)
				iCardsCount = iCardsCount + 1
			end
		end

		-- temp, iCardsCount, iNowValue)
		-- 判断合法之后，在判断牌型
		iNowType = JudgeCard:JudgeCardShape( temp, iCardsCount, iNowValue)		
		if iNowType ~= iCardType or iNowValue ~= iCardValue then
			local error_msg = string.format("ddz牌型牌值错误iNowType[%d]iCardType[%d]iNowValue[%d]iCardValue[%d]", iNowType, iCardType, iNowValue, iCardValue)
			self:handlingError(error_msg)
			return "ERROR"
		end

		if iNowType == -1 then
			local error_msg = string.format("ddz牌型牌值错误iNowType[%d]iCardType[%d]iNowValue[%d]iCardValue[%d]", iNowType, iCardType, iNowValue, iCardValue)
			self:handlingError(error_msg)
			return "ERROR"
		end

		-- 检测是否和当前桌面上的牌保持一致
		iCardsCount = 0
		temp = {}
		for i = 1, 20 do 
			if cCards[i] then
				temp[i] = math.floor(cCards[i] % 100)
				iCardsCount = iCardsCount + 1
			end
		end

		iOldType = JudgeCard:JudgeCardShape(temp, iCardsCount, iOldValue);

		local iAllow = 0
		if ((iNowValue == -1) or (iOldValue < 1 ) or (iOldType < 0)or (iOldType==iNowType and iNowValue>iOldValue) or (iNowType == JudgeCard.TYPE_ROCKET_CARD) or ( iNowType == TYPE_BOMB_CARD and iOldType  ~= JudgeCard.TYPE_BOMB_CARD and iOldType ~= JudgeCard.TYPE_ROCKET_CARD)) then
			-- local error_msg = string.format("ddz牌型牌值错误,  没有当前桌面上的牌值大iNowType[%d]iCardType[%d]iNowValue[%d]iCardValue[%d]", iNowType, iCardType, iNowValue, iCardValue)
			-- self:handlingError(error_msg)
			-- return "ERROR"

			iAllow = 1;
		end

		if iTableNumExtra ~= self.iCurPlayExtraNum then
			if(iAllow==0) then
				-- 踢人动作
				local error_msg = string.format("玩家出的牌没桌面上的牌大，可能用外挂，逃跑处理iNowType[%d]iCardType[%d]iNowValue[%d]iCardValue[%d]", iNowType, iCardType, iNowValue, iCardValue)
				self:handlingError(error_msg)
				return "ERROR"
			end
		end


		if (iNowType == JudgeCard.TYPE_ROCKET_CARD or iNowType == JudgeCard.TYPE_BOMB_CARD) then
			
			if self.iNowBoom < self.iMaxBoom then
				self.iRoomTime = self.iRoomTime * 2
			end
			-- 不管几炸， 全部都加上去
			self.iNowBoom = self.iNowBoom + 1
		end

		-- 删除手中的牌(手牌20张， 值可能为0 但是不会为空)
		for i = 1, 20 do
			if not cCards[i] then
				break
			end 
			for j = 1, 20 do 
				if player.handle_cards[j] == cCards[i] then
					player.handle_cards[j] = 0
					for z = j, 20 do 
						player.handle_cards[z] = player.handle_cards[z+1]
						player.handle_cards[z+1] = 0
					end
				end
			end			
		end

		-- 标记现在桌面上出牌的人是谁（牌权）
		self.iCurPlayExtraNum = iTableNumExtra;
	else  
		-- 如果是Pass的话

		iNowType = 0;    -- 牌型置0
		iNowValue = 0;   -- 键牌值置0
	end


	-- 确定剩下的牌数

	local iCardLeft = 0

	for i = 1, 20 do 
		if player.handle_cards[i] ~= 0 then
			iCardLeft = iCardLeft + 1
		end
	end

	-- 通知出牌

	local msgNotice = {}

	-- cardList
	msgNotice.cCards = cCards
	msgNotice.userExtra = iTableNumExtra
	msgNotice.cCardNum = iCardNum
	msgNotice.cCardType = iCardType
	msgNotice.cCardValue = iCardValue

	-- 剩余牌数， 给前端显示用
	msgNotice.cLestCardNum = iCardLeft

	self.room:broadcastAllPlayers("NOTICE_SEND_CARD", msgNotice)

	-- 扔在自己出牌的数组里面
	for j = 1, iCardNum do 
		for i = 1, 20 do 
			if self.cSendCards[iTableNumExtra][i] == nil then	
				self.cSendCards[iTableNumExtra][i] =  cCards[j]
				break
			end 
		end
	end

	-- for (i=0; i<20; i++)
	for i = 1, 20 do 
		while true do 
			if self.cSendNum[iTableNumExtra][i] ~= 0 then
				break;
			end

			if iCardType == Judgecard.TYPE_ROCKET_CARD then
				self.cSendNum[iTableNumExtra][i] = 100
			elseif iCardType == Judgecard.TYPE_BOMB_CARD then
				self.cSendNum[iTableNumExtra][i] = 99
			else
				self.cSendNum[iTableNumExtra][i] = iCardNum
			end
			break
		end	
	end

	-- 牌局结束,  算分
	if iCardLeft == 0 then
		local bIfSpring = false
		-- 地主赢了
		if iTableNumExtra == self.iMainPlayer then

			local iTempCardNum = {0, 0}
			local iPlayer = 1

			for i = 1, 3 do 
				if i ~= iTableNumExtra then
					local player = self.room:getPlayerByPos(i)
					for j = 1, 20 do 
						if player.handle_cards[j] ~= 0 then
							iTempCardNum[iPlayer] = iTempCardNum[iPlayer] + 1
						end
					end

					iPlayer = iPlayer + 1
				end
			end

			if 	iTempCardNum[1] == 17 and iTempCardNum[2] == 17 then
				self.iRoomTime = self.iRoomTime * 2;
				bIfSpring = true;
			end		

		else
			if self.iTurn == 1 then
				-- 炸弹和底分都已经在这里面有加倍， 那就看个人是否加倍吧
				self.iRoomTime = self.iRoomTime * 2;
				bIfSpring = true;
			end
		end

		-- 先算出来底分和叫分的基础番数， 最后再算出来每个玩家需要的番数
		-- 取得炸弹番数， 炸弹翻倍， 是指数
		-- local iBoomNum = self.iNowBoom >= self.iMaxBoom and self.iMaxBoom or self.iNowBoom
		-- local iBoutResult = iBoomNum + 1
		
		local iBoutResult = self.iRoomTime -- 乘以底分之后的


		for i = 1,  3 do 
			if i ~= iTableExtraNum then	
				local bTempTime = 1
				if self.bDoubleTime[i] == true then
					bTempTime = bTempTime * 2
				end 
				if self.bDoubleTime[iTableExtraNum] == true then
					bTempTime = bTempTime * 2				
				end

				-- local player1 = self.room:getPlayerByPos(i)
				-- local player2 = self.room:getPlayerByPos(iTableExtraNum)
				-- 算分
				self.iAmountResult[i] = self.iAmountResult[i] + (-1)*self.iRoomTime*bTempTime
				self.iAmountResult[iTableExtraNum] = self.iAmountResult[iTableExtraNum] + self.iRoomTime*bTempTime
			end
		end

		-- 把分数加载到玩家的身上去
		for i = 1, 3 do 
			local player = self.room:getPlayerByPos(i)
			player.cur_score = self.iAmountResult[i]
			player.score = player.score + self.iAmountResult[i]
		end
		-- 通知结算信息
		local resultMsg = {}

		-- required int32 	over_type = 1;     	// 1 正常结束 2 流局 3 房间解散会发送一个结算
		-- repeated Item 	players = 2;       	// 玩家的信息 * 3
		-- required bool  	bIfSpring = 2;		// 是否春天
		-- required int32 	iTime = 3;			// 房间倍数
		-- required int32 	iBoomNums = 4;		// 炸弹的个数
		-- iLastCard
		resultMsg.over_type = self.room:get("cur_round") >= self.room:get("round")
		resultMsg.players = self.room:get("players")
		resultMsg.bIfSpring = bIfSpring
		resultMsg.iTime = self.iRoomTime
		resultMsg.iBoomNums = self.iNowBoom

		-- 通知玩家游戏结束了
		self.room:broadcastAllPlayers("NOTICE_DDZ_GAME_OVER", resultMsg)

		return "success"
	else   -- 通知下个人出牌
		local iJudgeCard = iTableNumExtra + 1

		if iJudgeCard > 3 then
			iJudgeCard = 1
		end

		self.iCurPlayExtraNum = iJudgeCard
		self:serverPushPlayCard(self.iCurPlayExtraNum)
	end


	return "success"
end


function game:gameCMD(data)
	local user_id = data.user_id
	local command = data.command
	local func = game[command]
	if not func then
		return "no_support_command"
	end

	local player = self.room:getPlayerByUserId(user_id)
	local result = func(game,player,data)
	return result
end

return game

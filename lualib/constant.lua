local constant = {}

local MJ_CARDS_TYPE = {
	[1] = "🀇",
	[2] = "🀈",
	[3] = "🀉",
	[4] = "🀊",
	[5] = "🀋",
	[6] = "🀌",
	[7] = "🀍",
	[8] = "🀎",
	[9] = "🀏",

	[11] = "🀐",
	[12] = "🀑",
	[13] = "🀒",
	[14] = "🀓",
	[15] = "🀔",
	[16] = "🀕",
	[17] = "🀖",
	[18] = "🀗",
	[19] = "🀘",

	[21] = "🀙",
	[22] = "🀚",
	[23] = "🀛",
	[24] = "🀜",
	[25] = "🀝",
	[26] = "🀞",
	[27] = "🀟",
	[28] = "🀠",
	[29] = "🀡",

	[31] = "🀁",
	[32] = "🀂",
	[33] = "🀃",
	[34] = "🀄",
	[35] = "🀅",
	[36] = "🀆"
}

constant["ZJ_MODE"] = {
	LIAN_ZHUANG = 1,	 --连庄  每局一个庄家
	YING_ZHUANG = 2      --谁赢谁坐庄
}

constant["PLAYER_STATE"] = {
	UN_PREPARE = 1,		--未准备
	PREPARE_FINISH = 2, --准备完毕  
	DEAL_FINISH = 3,	--发牌完毕
	GAME_PLAYING = 3,	--游戏进行中
	GAME_OVER = 4		--游戏结束
}

constant["PUSH_EVENT"] = {
	REFRESH_ROOM_INFO = "refresh_room_info", --刷新房间信息
	DEAL_CARD = "deal_card", --发牌 开局发牌
	DEAL_ONE_CARD = "deal_a_card", --发一张牌
	ZI_MO = "zi_mo",--胡牌
	NOTICE_OTHER_DEAL = "notice_other_deal", --通知其他人 有人摸牌了
	NOTICE_PLAYER_STATE = "notice_player_state",  --通知其他人的碰、杠、胡状态
	NOTICE_CHU_PAI = "notice_chu_pai", --通知其他人有人出牌了
	NOTICE_GAME_OVER = "notice_game_over", --本局结束

}
-----------------------游戏类型配置相关--------------------------

constant["ALL_GAME_TYPE"] = {
	["HZMJ"] = 1,
}
constant["ALL_GAME_NUMS"] = {
	["HZMJ"] = 4,
}
--红中麻将所有牌型
constant["ALL_CARDS"] = {
	["HZMJ"] = {
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,34,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,34,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,34,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,34
	}
}

constant["ALL_DEAL_NUM"] = {
	["HZMJ"] = 13,
}

constant["ALL_ZJ_MODE"] = {
	["HZMJ"] = constant["ZJ_MODE"]["YING_ZHUANG"],
}

constant["COMMAND"] = {
	CHI = 1,
	PENG = 2,
	GANG = 3,
	HU_PAI =4,
	CHU_PAI = 5,
}

constant["ALL_COMMAND"] = {
	["HZMJ"] = {"PENG","GANG","CHU_PAI"}
}

constant["OPERATER"] = {
	PENG = "PENG",
	GANG = "GANG",
	HU = "HU"
}



return constant
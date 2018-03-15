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
	[34] = "🀅",
	[35] = "🀄",
	[36] = "🀆"
}



constant["PLAYER_STATE"] = {
	UN_SIT_DOWN = 1,	--未入座
	SIT_DOWN_FINISH = 2, --入座完毕  
	DEAL_FINISH = 3,	--发牌完毕
	GAME_PLAYING = 3,	--游戏进行中
	GAME_OVER = 4		--游戏结束
}

constant["PUSH_EVENT"] = {
	PUSH_USER_INFO = "push_user_info",  --推送玩家的基本信息
	REFRESH_ROOM_INFO = "refresh_room_info", --刷新房间信息
	PUSH_SIT_DOWN = "push_sit_down",      --推送玩家坐下的信息
	DEAL_CARD = "deal_card", --发牌
	PUSH_DRAW_CARD = "push_draw_card", --摸牌通知
	PUSH_PLAY_CARD = "push_play_card", --通知玩家  该出牌了
	NOTICE_PLAY_CARD = "notice_play_card", --通知有人出牌
	NOTICE_PENG_CARD = "notice_peng_card",--通知有人碰牌了
	NOTICE_GANG_CARD = "notice_gang_card",--通知有人杠拍了
	PUSH_OPERATOR_PALYER_STATE = "push_player_operator_state", --通知客户端是否 碰/杠/胡
	NOTICE_GAME_OVER = "notice_game_over", --本局结束

}
-----------------------游戏类型配置相关--------------------------

--通用常量配置
constant["PAY_TYPE"] = {
	["ROOM_OWNER_COST"] = 1;  --房主出资
	["AMORTIZED_COST"] = 2;   --平摊
	["WINNER_COST"] = 3;      --赢家出资
}

constant["OTHER_SETTING"] = {
	["HZMJ"] = {
		[1] = "底分",
		[2] = "奖码数",
		[3] = "七对", -- 0代表不开启,1代表开启
		[4] = "喜分", -- 0代表不开启,1代表开启
		[5] = "一码不中当全中", --0代表不开启,1代表开启
	}
}

constant["GAME_OVER_TYPE"] = {
	["NORMAL"] = 1; --正常胡牌
	["FLOW"] = 2;	--流局
}
-----------------------游戏选择配置-------------------
--所有的游戏类型
constant["ALL_GAME_TYPE"] = {
	["HZMJ"] = 1,
}

constant["RECOVER_GAME_TYPE"] = {}
for k,v in pairs(constant["ALL_GAME_TYPE"]) do
	constant["RECOVER_GAME_TYPE"][v] = k
end

--所有游戏的牌型
constant["ALL_CARDS"] = {
	["HZMJ"] = {
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35
	}
}

--所有游戏的坐庄模式
----LIAN 连庄  每局一个庄家  YING --谁赢谁坐庄
constant["ALL_ZJ_MODE"] = {
	["HZMJ"] = "YING",
}

constant["ZJ_MODE"] = {
	["YING"] = "YING",
	["LIAN"] = "LIAN",
}


----------------------网络事件常量----------------
constant["NET_EVENT"] = {
	HANDSHAKE = "handshake",
	LOGIN = "login",
	RECONNECT = "reconnect",
	LOGOUT = "logout",
	CREATE_ROOM = "create_room",
	JOIN_ROOM = "join_room",
	SIT_DOWN = "sit_down",
	FINISH_DEAL = "finish_deal",
	LEAVE_ROOM = "leave_room",
	GAME_CMD = "game_cmd",
}

constant["GANG_TYPE"] = {
	AN_GANG = 1,
	MING_GANG = 2;
	PENG_GANG = 3;
}


constant["GAME_CMD"] = {
	DEAL_FINISH = "DEAL_FINISH",	--发牌完毕

}

constant["NET_RESULT"] = {
	SUCCESS = "success",
	ALREADY_IN_ROOM = "already_in_room",
	FAIL = "fail",
	AUTH_FAIL = "auth_fail",
	NOT_EXIST_ROOM = "not_exist_room",
	SIT_ALREADY_HAS = "sit_already_has",
	NOSUPPORT_COMMAND = "nosupport_command",
	NO_CARD = "no_card",

}

 


return constant
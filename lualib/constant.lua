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



constant["ROOM_STATE"] = {
	GAME_PREPARE = 1,   --游戏准备阶段
	GAME_PLAYING = 2,	--游戏中
	GAME_OVER = 3,		--游戏结束
	ROOM_DISTROY = 4,   --房间被销毁
}

constant["PUSH_EVENT"] = {
	PUSH_USER_INFO = "push_user_info",  		--推送玩家的基本信息
	REFRESH_ROOM_INFO = "refresh_room_info", 	--刷新房间信息
	PUSH_SIT_DOWN = "push_sit_down",      		--推送玩家坐下的信息
	DEAL_CARD = "deal_card", 					--发牌
	PUSH_DRAW_CARD = "push_draw_card", 			--摸牌通知
	PUSH_PLAY_CARD = "push_play_card", 			--通知玩家  该出牌了
	NOTICE_PLAY_CARD = "notice_play_card", 		--通知有人出牌
	NOTICE_PENG_CARD = "notice_peng_card",		--通知有人碰牌了
	NOTICE_GANG_CARD = "notice_gang_card",		--通知有人杠拍了
	PUSH_OPERATOR_PALYER_STATE = "push_player_operator_state", 	--通知客户端是否 碰/杠/胡
	NOTICE_GAME_OVER = "notice_game_over", 		--本局结束
	NOTICE_PLAYERS_DISCONNECT = "notice_players_disconnect", 	--通知玩家有人掉线
	HANDLE_ERROR = "handle_error", 				--错误处理
	PUSH_DEMAND_POINT = "push_demand_point",	--通知玩家叫分

	-- ddz_msg
	SERVER_SEND_CARD  = "ServerSendCard",
	NOTICE_POINT_DEMAND  = "NoticePointDemand",
	NOTICE_MAIN_PALAYER = "NoticeMainPaleyer",
	NOTICE_SEND_CARD = "NoticeSendCard",
	SERVER_POINT_DEMAND = "ServerPointDemand",
	NOTICE_DDZ_GAME_OVER = "NoticeDDZGameOver",


	-- 

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

-----------------------游戏选择配置-------------------
--所有的游戏类型
constant["ALL_GAME_TYPE"] = {
	["HZMJ"] = 1,
	["DDZ"] = 2,
}

constant["RECOVER_GAME_TYPE"] = {}
for k,v in pairs(constant["ALL_GAME_TYPE"]) do
	constant["RECOVER_GAME_TYPE"][v] = k
end

--所有游戏的牌型
constant["ALL_CARDS"] = {
	[1] = {
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35,
		1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,35
	},
	[2] = {
		103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 120, 
		203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 220, 
		303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 320, 
		403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 420, 
		124, 125
	}
}

--所有游戏的坐庄模式
----LIAN 连庄  每局一个庄家  YING --谁赢谁坐庄
constant["ALL_ZJ_MODE"] = {
	[1] = "YING",
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

constant["GAME_CMD"] = {
	DEAL_FINISH = "DEAL_FINISH",	--发牌完毕
	DEMAND = "DEMAND"
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
	NO_BIND_ROOM_ID = "no_bind_room_id",
	CALL_CENTER_FAIL = "call_center_fail",
	INVALID_PARAMATER = "invalid_paramater",
	ROUND_NOT_ENOUGH = "round_not_enough",
}

constant["DEBUG"] = true


constant["DISTORY_TYPE"] = {
	ALL_AGREE = 1,     -- 申请并所有人都同意
	OWNER_DISTROY = 2, -- 房主解散
	EXPIRE_TIME = 3,   -- 房间的时间过期
}

constant["ACCOUNT_DB"] = 0
constant["ROUND_COST"] = 5

--自动同意时间
constant["AUTO_CONFIRM"] = 2*60* 100


constant["WINNER_TYPE"] = {
	ZIMO = 1,
	QIANG_GANG = 2,
}




return constant
local constant = {}

constant.PLAY_TYPE = {
	COMMAND_PRE_START    = 1,   --牌局开始前
    COMMAND_START        = 2,   --牌局开始

    COMMAND_CAN_PLAY_CARD = 3,  --可以打牌
    COMMAND_PLAY_CARD = 4,  --可以打牌

    COMMAND_CAN_PASS = 5,   --可以过
    COMMAND_PASS = 6,    --过

    COMMAND_CAN_CHI = 7,  --可以吃
    COMMAND_CHI = 8,    --吃

    COMMAND_CAN_PENG = 9,  --可以碰
    COMMAND_PENG = 10,   --碰

    COMMAND_CAN_AN_GANG = 11, --可以暗杠
    COMMAND_AN_GANG = 12,   --暗杠

    COMMAND_CAN_BU_GANG = 13, --可以补杠
    COMMAND_BU_GANG = 14,      --补杠

    COMMAND_CAN_GANG_A_CARD = 15,   --可以明杠

    COMMAND_GANG_A_CARD = 16,  -- /** 杠牌 */

    COMMAND_CAN_TING_CARD = 17,    --可以听牌
    COMMAND_TING_CARD = 18,        --听牌

    COMMAND_CAN_HU = 19,        --可以胡
    COMMAND_HU = 20,            --胡


 
    COMMAND_HANDLE_CARDS = 21,     --手牌(开局发牌/重新加入房间复牌/胡牌后公开手牌) */
    COMMAND_DEAL_CARD = 22,        --抓牌
    COMMAND_LIGHT = 23,            --断线重连指示灯
    COMMAND_TING_TIP = 24,         --听牌提示

    COMMAND_TRUSTEESHIP   = 25,       --托管
    COMMAND_TRUSTEESHIP_CANCEL = 26,  --取消托管
    COMMAND_TRUSTEESHIP_DELAY_TIME   = 27,  --延迟托管时间 XX秒后将会托管


    -- /** 可以自动出牌 自动打出最后摸的牌 */
    COMMAND_CAN_AUTO_PLAY_LAST_DEALED_CARD = 28,

    -- /** 剩余牌池 */
    DISPLAY_LAST_CARD_COUNT = 29,

    

    --结算相关
    -- /** 平胡 */
    HU_PING_HU               = 1000,
    -- /** 七对 */
    HU_QI_DUI                = 1001,
    -- /** 十三幺 */
    HU_SHI_SAN_YAO           = 1002,
    -- /** 清一色 */
    HU_QING_YI_SE            = 1003,
    -- /** 一条龙 */
    HU_YI_TIAO_LONG          = 1004,
    -- /** 杠上胡 */
    HU_QIANG_GANG_HU         = 1019,
    -- /** 点炮胡, 对应于自摸 */
    HU_DIAN_PAO              = 1023,
    -- /** 缺一门 */
    HU_QUE_YI_MEN            = 1033,
    -- /** 边张 */
    HU_BIAN_ZHANG            = 1034,
    -- /** 坎张 */
    HU_KAN_ZHANG             = 1035,
    -- /** 单钓 */
    HU_DAN_DIAO              = 1036,
    -- /** 够张 */
    HU_GOU_ZHANG             = 1037,
    -- /** 庄家 */
    HU_ZHUANG_JIA            = 1038,

    -- /** 被吃 */
    DISPLAY_BE_CHI                     = 3000,
    -- /** 被碰 */
    DISPLAY_BE_PENG                    = 3001,
    -- /** 点杠 */
    DISPLAY_BE_GANG                    = 3002,
    -- /** 自摸加番 */
    DISPLAY_ZIMO_FAN                   = 3003,
    -- /** 自摸加分 */
    DISPLAY_ZIMO_FEN                   = 3004,
     -- /** 奖码 */
    DISPLAY_BETTING_HORSE              = 3014,

    -- /** GPS检测开 */
    GPS_CHECK_OPEN = 65525,
    -- /** GPS检测关 */
    GPS_CHECK_CLOSE = 65524,
}

constant.CLIENT_PLAY_TYPE = {
    
     
}


constant.CARD_TYPE = {
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

	[31] = "🀀",   --东
	[32] = "🀁",   --南
	[33] = "🀂",   --西
	[34] = "🀃",   --北
	[35] = "🀄",  --中
	[36] = "🀅",   --发
	[37] = "🀆",   --白
	
	[41] = "🀦",   --春
	[42] = "🀧",   --夏
	[43] = "🀨",   --秋
	[44] = "🀩",   --冬
	[45] = "🀢",   --梅
	[46] = "🀣",   --兰
	[47] = "🀤",   --竹
	[48] = "🀥",   --菊


	[49] = "🀪"    --百搭
}
return constant
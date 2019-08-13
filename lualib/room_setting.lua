local room_setting = {}
--通用规则
room_setting.GAME_PLAY_CODE = {
    -- 二人房
    [10001] = PLAYER_TWO,
    -- 三人房
    [10002] = PLAYER_THREE,
    -- 四人房
    [10003] = PLAYER_FOUR,

    -- 房主付费 AA付费  大赢家付费、俱乐部经理付费
    [11001] = PAY_BY_ROOMOWNER,
    [11002] = PAY_BY_WINNER,
    [11003] = PAY_BY_AA,
    [11004] = PAY_BY_CLUBOWNER,

    [12001] = ROOM_COUNT_ROUND_8,   --8局
    [12001] = ROOM_COUNT_ROUND_16,  --16局
    [12001] = ROOM_COUNT_CIRCLE_1,  --1圈
    [12001] = ROOM_COUNT_CIRCLE_2,  --2圈
    [12001] = ROOM_COUNT_CIRCLE_3,  --3圈

	--点炮一家出
    [12001] = GAME_RULES_PAY_ONE,
    --点炮三家出
    [12002] = GAME_RULES_PAY_THREE,
    
    -- 红中麻将
    [1000001] = GAME_TYPE_HONGZHONG,
    -- 斗地主
    [1000002] = GAME_TYPE_JING_DIAN,
    --跑得快
    [1000003] = GAME_TYPE_PAO_DE_KUAI,
}

room_setting.GAME_PLAY_NAME = {}
local keys = table.keys(room_setting.GAME_PLAY_CODE)
for _,key in ipairs(keys) do
    local name = room_setting.GAME_PLAY_CODE[key]
    room_setting.GAME_PLAY_NAME[name] = key
end

room_setting.CONVERT_PLAYER_NUM = {
    PLAYER_TWO = 2,
    PLAYER_THREE = 3,
    PLAYER_FOUR = 4
}

room_setting.CONVERT_ROUND_NUM = {
    ROOM_COUNT_ROUND_8  = { num = 8, isCircle = false },   --8局
    ROOM_COUNT_ROUND_16 = { num = 16, isCircle = false },  --16局
    ROOM_COUNT_CIRCLE_1 = { num = 1, isCircle = true },  --1圈
    ROOM_COUNT_CIRCLE_2 = { num = 2, isCircle = true },  --2圈
    ROOM_COUNT_CIRCLE_3 = { num = 3, isCircle = true },  --3圈
}








return room_setting
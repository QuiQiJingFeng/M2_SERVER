CREATE DATABASE IF NOT EXISTS lsj_game default char set utf8;
use lsj_game;

-- 用户的注册信息表
CREATE TABLE register
(
	user_id         int(10) auto_increment,  -- 玩家的ID
    group_id        int,                     -- 用户组ID  0 表示超级管理员用户 1 表示管理员用户  2 表示普通用户
    user_ip         varchar(20),             -- 玩家最后注册的IP
    account         varchar(255),            -- 玩家的账户
    password        varchar(200),            -- 玩家的密码 MD5 (平台的登陆因为需要向平台去验证,所以这里不需要存储)
	login_type      varchar(20),             -- debug/release 如果是debug模式，同时用户的权限 <2 则不进行平台校验直接登录
    platform        varchar(20),             -- 玩家登陆的平台 WEICHAT/QQ
    device_id       varchar(100),            -- 设备ID
    device_type     varchar(100),            -- 设备的型号 MI141
    time            datetime,                -- 注册的时间
    bind_id         int(10),                 -- web账号绑定的游戏ID
    primary key(user_id,account)
);
-- 定义user_id 的自增ID 从10001开始
ALTER TABLE register AUTO_INCREMENT = 10001;

-- 用户登录的记录表
CREATE TABLE login
(
	user_id         int(10),                -- 玩家ID
    user_ip         varchar(20),           -- 玩家登陆的IP
    account         varchar(255),          -- 玩家的账户
	login_type      varchar(20),           -- 玩家登陆的类型 WEICHAT/QQ
    platform        varchar(20),           -- 玩家登陆的渠道 IOS/Android
    device_id       varchar(100),          -- 设备ID
    device_type     varchar(100),          -- 设备的型号 MI141 
    time            datetime               -- 玩家登陆的时间
);

-- 用户退出的记录表
CREATE TABLE logout
(
	user_id         int(10),               -- 玩家ID
    time            datetime               -- 玩家退出的时间
);

-- 玩家的信息表
CREATE TABLE user_info
(
	user_id         int(10),                -- 玩家的ID
    user_name       varchar(255),           -- 玩家的名字
    user_ip         varchar(20),            -- 玩家最后登陆的IP
    user_pic        varchar(255),           -- 玩家头像的地址
    gold_num        double,                 -- 玩家的金币数量
    start           int,                    -- 用户的星级
    pre_user_id     int(10),                -- 上级的代理ID
    invite_code     text,                   -- 自身所在的5级代理链 (user_id-user_id-user_id...)
    total_pay       float,                  -- 总充值
    today_rebate    float,                  -- 成为下级代理之后的总充值
    reduce_rebate   float,                  -- 剩余可提现的返利
    bind_time       datetime,               -- 成为下级代理的时间
    sex             int(1),                 -- 性别 男为1
    adress          varchar(255),           -- 地址
    primary key(user_id)
);

-- 房间的创建记录
CREATE TABLE create_room
(
	user_id         int(10),                -- 玩家ID
	room_id         int(10),                -- 房间号
    game_type       int,                    -- 游戏的类型
    round           int,                    -- 圈数
    pay_type        int,                    -- 支付类型
    seat_num        int,                    -- 游戏的人数
    over_round      int,                    -- 已经结束的局数
    other_setting   varchar(200),           -- 其他设定
    is_friend_room  boolean,                -- 是否好友房
    is_open_voice   boolean,                -- 是否开启语音聊天
    is_open_gps     boolean,                -- 是否开启gps
    time            datetime                -- 创建时间
);

-- 房间的加入记录
CREATE TABLE join_room
(
	user_id         int(10),                -- 玩家ID
    room_id         int(10),                -- 房间号
    game_type       int,                    -- 游戏的类型
    time            datetime                -- 加入时间
);


-- 离开房间的记录
CREATE TABLE leave_room
(
	user_id         int(10),                -- 玩家ID
    room_id         int(10),                -- 房间ID
    game_type       int,                    -- 游戏的类型
    time            datetime                -- 离开房间的时间
);

-- 当前存在的房间的列表
CREATE TABLE room_list                      
(
    owner_id        int(10),                -- 拥有者的ID
    room_id         int(10),                -- 房间ID
    game_type       int,                    -- 游戏的类型
    round           int,                    -- 圈数
    pay_type        int,                    -- 支付类型
    seat_num        int,                    -- 游戏的人数
    over_round      int,                    -- 已经结束的局数
    cur_round       int,                    -- 当前的回合数量
    sit_down_num    int,                    -- 已经坐下的人数
    other_setting   varchar(200),           -- 其他设定
    is_friend_room  boolean,                -- 是否好友房
    is_open_voice   boolean,                -- 是否开启语音聊天
    is_open_gps     boolean,                -- 是否开启gps
    player_list     text,                   -- 玩家列表
    server_id       int,                    -- 服务器ID
    state           int,                    -- 当前房间的状态
    expire_time     double,                 -- 房间的释放时间
    begin_time      datetime,               -- 开始时间
    primary key(room_id)
);

-- 资源变化的记录
CREATE TABLE resource
(
     user_id        int(10),                 -- 玩家ID
     resource_type  int,                     -- 资源类型 1 = 金币
     source         int,                     -- 资源变化来源 1 = 开房  2 = 充值 3 = 抽奖
     old_num        double,                  -- 旧的数量
     new_num        double,                  -- 新的数量
     arg1           varchar(100),            -- 额外记录参数1
     arg2           varchar(100),            -- 额外记录参数2
     arg3           varchar(100)             -- 额外记录参数3
);


-- 房间服务器列表
CREATE TABLE room_servers
(
	server_id       int,                     -- 服务器ID
    game_type       int,                     -- 游戏类型
    server_host     varchar(50),             -- 服务器地址
    server_port     int,                      -- 服务器端口号
    primary key(game_type,server_host,server_port)
);

INSERT INTO room_servers values(1,1,"47.52.99.120",8888);
INSERT INTO room_servers values(2,2,"47.52.99.120",8889);


-- 对局记录
CREATE TABLE replay_ids
(
    replay_id      int auto_increment,       -- 战局编号
    room_id        double,                   -- 房间编号
    players        text,                     -- 房间中的玩家
    game_type      int,                      -- 游戏的类型
    time           datetime,                 -- 对战时间

    primary key(replay_id)               
);
-- 定义replay_id 的自增ID 从100开始
ALTER TABLE replay_ids AUTO_INCREMENT = 100;

-- 激活码列表
CREATE TABLE active_code_list
(
    user_id         int(10),      -- 用户ID
    active_code     varchar(100),      -- 激活码
    active_id       int(10),    -- 激活的用户ID
    active_time     datetime,  -- 激活的时间
    primary key(active_code)  
);


-- 支付列表
CREATE TABLE pay_orders(
    user_id        int(10),     -- 用户ID
    platform       varchar(30), -- 支付平台 weixin alipay
    order_id       varchar(30), -- 订单号
    item_id        varchar(30), -- 支付项 ID
    price          float,       -- 支付项价格
    gold_num       float,       -- 支付项 的总金币数量(包含赠送的数量)
    state          varchar(10)  -- 支付的状态 new/checking/faild/success
);















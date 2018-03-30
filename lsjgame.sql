


-- 用户的注册信息表
CREATE TABLE register_log
(
	user_id         varchar(11),          -- 玩家的ID
    user_ip         varchar(20),          -- 玩家最后注册的IP
    account         varchar(255),         -- 玩家的账户
    password        varchar(200),         -- 玩家的密码 MD5 (平台的登陆因为需要向平台去验证,所以这里不需要存储)
	login_type      varchar(20),          -- 玩家登陆的平台 WEICHAT/QQ
    platform        varchar(20),          -- 玩家登陆的渠道 IOS/Android
    device_id       varchar(100),         -- 设备ID
    device_type     varchar(100),         -- 设备的型号 MI141
    time            datetime,             -- 注册的时间
    primary key(user_id)
);


-- 用户登录的记录表
CREATE TABLE login_log
(
	user_id         varchar(11),           -- 玩家ID
    user_ip         varchar(20),           -- 玩家登陆的IP
    account         varchar(255),          -- 玩家的账户
	login_type      varchar(20),           -- 玩家登陆的类型 WEICHAT/QQ
    platform        varchar(20),           -- 玩家登陆的渠道 IOS/Android
    device_id       varchar(100),          -- 设备ID
    device_type     varchar(100),          -- 设备的型号 MI141 
    time            datetime,              -- 玩家登陆的时间
    primary key(user_id)
);

-- 用户退出的记录表
CREATE TABLE logout_log
(
	user_id         varchar(11),           -- 玩家IDlogin_log
    time            datetime               -- 玩家退出的时间
);

-- 玩家的信息表
CREATE TABLE user_info
(
	user_id         varchar(11),            -- 玩家的ID
    user_name       varchar(255),           -- 玩家的名字
    user_ip         varchar(20),            -- 玩家最后登陆的IP
    user_pic        varchar(255),           -- 玩家头像的地址
    gold_num        double,                 -- 玩家的金币数量
    primary key(user_id)
);

-- 房间的创建记录
CREATE TABLE create_room
(
	user_id         varchar(11),            -- 玩家ID
	room_id         int,                    -- 房间号
    time            datetime                -- 创建时间
);

-- 房间的加入记录
CREATE TABLE join_room
(
	user_id         varchar(11),            -- 玩家ID
    room_id         int,                    -- 房间号
    time            datetime                -- 加入时间
);


-- 离开房间的记录
CREATE TABLE leave_room
(
	user_id         varchar(11),            -- 玩家ID
    room_id         int,                    -- 房间ID
    time            datetime                -- 离开房间的时间
);

-- 资源变化的记录
CREATE TABLE resource_log
(
     user_id        varchar(11),             -- 玩家ID
     resource_type  int,                     -- 资源类型 1 = 金币
     source         int,                     -- 资源变化来源 1 = 开房  2 = 充值 3 = 抽奖
     old_num        double,                  -- 旧的数量
     new_num        double,                  -- 新的数量
     arg1           varchar(100),            -- 额外记录参数1
     arg2           varchar(100),            -- 额外记录参数2
     arg3           varchar(100)             -- 额外记录参数3
);
























CREATE DATABASE IF NOT EXISTS lsj_game default char set utf8;
use lsj_game;

CREATE TABLE generators
(
	user_id_generator double
);

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
    primary key(user_id)
);

-- 房间的创建记录
CREATE TABLE create_room
(
	user_id         int(10),            -- 玩家ID
	room_id         int,                    -- 房间号
    time            datetime                -- 创建时间
);

-- 房间的加入记录
CREATE TABLE join_room
(
	user_id         int(10),            -- 玩家ID
    room_id         int,                    -- 房间号
    time            datetime                -- 加入时间
);


-- 离开房间的记录
CREATE TABLE leave_room
(
	user_id         int(10),            -- 玩家ID
    room_id         int,                    -- 房间ID
    time            datetime                -- 离开房间的时间
);

-- 资源变化的记录
CREATE TABLE resource
(
     user_id        int(10),             -- 玩家ID
     resource_type  int,                     -- 资源类型 1 = 金币
     source         int,                     -- 资源变化来源 1 = 开房  2 = 充值 3 = 抽奖
     old_num        double,                  -- 旧的数量
     new_num        double,                  -- 新的数量
     arg1           varchar(100),            -- 额外记录参数1
     arg2           varchar(100),            -- 额外记录参数2
     arg3           varchar(100)             -- 额外记录参数3
);


























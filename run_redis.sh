#!/bin/bash
MODE=$1

if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform
    REDIS=redis-server
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under Linux platform
    REDIS=redis-server
fi

#检查redis.conf文件是否存在
CONF_DIR_PATH="config/redis/"
if [ ! -f "$CONF_DIR_PATH/redis.conf" ]; then
    echo "[ERROR] NO redis.conf in $CONF_DIR_PATH"
    exit 1
fi

if [ ! -f "$CONF_DIR_PATH/data/" ]; then
    mkdir $CONF_DIR_PATH/data
fi

if [ ! -f "$CONF_DIR_PATH/log/" ]; then
    mkdir $CONF_DIR_PATH/log
fi

if [ ! -n "$MODE" ]; then
    nohup $REDIS config/redis/redis.conf > config/redis/log/redis.log 2>&1 &
elif [ "$MODE" = "debug" ]; then
    $REDIS config/redis/redis.conf
else
    echo "[ERROR] UNKNOW PARAM2 $1"
    exit 1
fi
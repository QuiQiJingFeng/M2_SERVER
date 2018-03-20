
COMMON_DIR_PATH="service_common/log/"
if [ ! -d "$COMMON_DIR_PATH" ]; then
    mkdir "$COMMON_DIR_PATH"
fi
CENTER_DIR_PATH="service_center/log/"
if [ ! -d "$CENTER_DIR_PATH" ]; then
    mkdir "$CENTER_DIR_PATH"
fi
AGENT_DIR_PATH="service_agent/log/"
if [ ! -d "$AGENT_DIR_PATH" ]; then
    mkdir "$AGENT_DIR_PATH"
fi

touch service_common/log/print.log
touch service_center/log/print.log
touch service_agent/log/print.log

NAME="skynet"
PROCESS=`ps -ef | grep "$NAME" | grep -v "$0" | grep -v "grep" | awk '{print $2}'`  
for i in $PROCESS  
do  
  echo "Kill the $1 process [ $i ]"  
  kill $i  
done


if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform
    OSTYPE=osx
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under Linux platform
    OSTYPE=linux
	ulimit -n 65535
	ulimit -c unlimited
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
    # Do something under Windows NT platform
    OSTYPE=cygwin
fi

nohup ./skynet service_common/config.lua > service_common/log/print.log 2>&1 &
sleep 0.5
nohup ./skynet service_center/config.lua > service_center/log/print.log 2>&1 &
sleep 0.5
nohup ./skynet service_agent/config.lua > service_agent/log/print.log 2>&1 &

SERVER=$1
#检查启动参数
if [ ! -n "$SERVER" ]; then
    echo "[ERROR] NO SERVER TYPE!"
    exit 1
fi
touch conf/$SERVER/print.log

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

nohup ./skynet conf/$SERVER/config.lua > conf/$SERVER/print.log 2>&1 &

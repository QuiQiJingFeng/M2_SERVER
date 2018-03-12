local OrderedSet = {}

function OrderedSet.new(redis,orderedset_key)
    local property = {_redis = redis,_orderedset_key = orderedset_key}

    --@function 批量添加数据
    --@params score1,member1,score2,member2,...
    function property:add(...)
        self._redis:zadd(self._orderedset_key,...)
    end

    --@function 给member关联的score 增加score,如果member不存在则创建
    --@score 要增加的score
    --@member 指定的member
    function property:incrbyScore(score,member)
        self._redis:zincrby(self._orderedset_key,score,member)
    end

    --@function 返回集合中成员member的score值
    --@member 集合成员
    function property:score(member)
        return self._redis:zscore(self._orderedset_key,member)
    end

    --@function 返回score在min~max之间的数量 
    --@min 最小值 闭区间
    --@max 最大值 闭区间
    function property:count(min,max)
        return self._redis:zcount(self._orderedset_key,min,max)
    end

    --@function 移除集合中的元素
    --@params member1,member2...
    function property:remove(...)
        self._redis:zrem(self._orderedset_key,...)
    end

    --@function 移除集合中score处于min~max之间的成员
    --@min 最小值 闭区间
    --@max 最大值 闭区间
    function property:removeRangeByScore(min,max)
        self._redis:zremrangebyscore(self._orderedset_key,min,max)
    end

    --@function 移除集合中指定排名(rank)区间内的所有成员
    --@start 开始位置(闭区间)
    --@stop  结束位置(闭区间)
    function property:removeRangeByRank(start,stop)
        start = start - 1
        stop = stop - 1
        self._redis:zremrangebyrank(self._orderedset_key,start,stop)
    end

    --@function 返回指定的区间集合(score从小到大排列)
    --@start 开始位置(闭区间)
    --@stop  结束位置(闭区间)
    --@withscores 是否需要连分数一起返回
    --withscores=true则以 value1,score1, ..., valueN,scoreN 的格式返回
    function property:range(start,stop,withscores)
        start = start - 1
        stop = stop - 1
        withscores = withscores and 'WITHSCORES' or nil
        
        return self._redis:ZRANGE(self._orderedset_key,start,stop,withscores)
    end

    --@function 返回分数在min~max之间的成员
    --@min 最小值 闭区间
    --@max 最大值 闭区间
    --@withscores 是否返回分数
    --@limit_start limit_end 返回结果的区间 先闭后开区间 score从小到大排列
    function property:rangeByScore(min,max,withscores,limit_start,limit_end)
        local args = {}
        if withscores then
            table.insert(args,"WITHSCORES")
        end
        if limit_start and limit_end then
            table.insert(args,"limit")
            table.insert(args,limit_start-1)
            table.insert(args,limit_end-1)
        end
        return self._redis:zrangebyscore(self._orderedset_key,min,max,table.unpack(args))
    end

    --@function 返回集合中指定区间的成员(score从大到小排列)
    --@start 开始位置(闭区间)
    --@stop  结束位置(闭区间)
    --@withscores 是否返回分数
    function property:reverseRange(start,stop,withscores)
        start = start - 1
        stop = stop - 1
        local args = {}
        if withscores then
            table.insert(args,"WITHSCORES")
        end
        return self._redis:zrevrange(self._orderedset_key,start,stop,table.unpack(args))
    end

    --@function 返回member在有序集合中的排名  score值从大到小排列
    --@member 集合成员
    function property:reverseRank(member)
        return self._redis:zrevrank(self._orderedset_key,member) + 1
    end

    --@function 返回集合中score处于min~max之间的所有成员
    --@max 最大值 闭区间
    --@min 最小值 闭区间
    --@withscores 是否返回分数
    --@limit_start limit_end 返回结果的区间 先闭后开区间 score从大到小排列
    function property:reverseRangeByScore(max,min,withscores,limit_start,limit_end)
        local args = {}
        if withscores then
            table.insert(args,"WITHSCORES")
        end
        if limit_start and limit_end then
            table.insert(args,"limit")
            table.insert(args,limit_start-1)
            table.insert(args,limit_end-1)
        end
        
        return self._redis:zrevrangebyscore(self._orderedset_key,max,min,table.unpack(args))
    end

    --@function 返回member在有序集合中的排名score值递增(从小到大)顺序排列
    --@member 集合成员
    function property:rank(member)
        return self._redis:zrank(self._orderedset_key,member) + 1
    end

    return property
end

return OrderedSet


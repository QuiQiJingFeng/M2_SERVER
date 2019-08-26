local UIAnimationManager = class("UIAnimationManager")

local CONFIG = {
    ["TEST"] = { 
        path = "csb/Effect_redbox.csb",
        animations = {"redbox1","redbox2"}
    }
}

local _instance = nil
--------------------------------------------------------------
function UIAnimationManager:ctor()
 
end

function UIAnimationManager:getInstance()
    if _instance == nil then
        _instance = UIAnimationManager.new()
    end

    return _instance
end

function UIAnimationManager:destroy()
    if _instance then
        _instance:dispose()
    end
end

function UIAnimationManager:dispose()
end

--[[
获取当前动画实际时间
因为lua没有导出动画播放完成后的回调
因为是按照60FPS算的,所以跟实际上可能是有误差的
]]
function UIAnimationManager:getAnimTime(timeline)
    local speed = timeline:getTimeSpeed()
    local startFrame = timeline:getStartFrame()
    local endFrame = timeline:getEndFrame()
    local frameNum = endFrame - startFrame

    local isDone = timeline:isDone()
    return 1.0 /(speed * 60.0) * frameNum
end

function UIAnimationManager:playAnimation(name,actionIdx,parent,pos,zorder,finishFunc,delay,replay)
    local info = CONFIG[name]
    assert(info,string.format("Animation %s Not Exist",tostring(name)))
    assert(parent,"parent must be none nil")
    assert(info.animations[actionIdx],"action name must be none nil")
    self._animNode = cc.CSLoader:createNode(info.path)
    self._action = cc.CSLoader:createTimeline(info.path)
    self._animNode:runAction(self._action)
    parent:addChild(self._animNode)

    local callbackNode = cc.Node:create()
    self._animNode:addChild(callbackNode)

    replay = replay or false
    if pos then self._animNode:setPosition(pos) end
    if zorder then self._animNode:setLocalZOrder(zorder) end
    local info = self._action:getAnimationInfo(info.animations[actionIdx])
    self._action:gotoFrameAndPlay(info.startIndex, info.endIndex,replay)

    if finishFunc and not replay then
        delay = delay or 0
        local time = self:getAnimTime(self._action) + delay
        scheduleOnce(finishFunc,time,callbackNode)
    end
end

--[[
example:
    scheduleOnce(function() 
        local UIAnimationManager = require("app.manager.UIAnimationManager")
        UIAnimationManager:getInstance():playAnimation("TEST",1,self,display.center,0,function() 
            print("FYD-=---------END=======")
            self:setRotation(10)
        end)
    end,1)
]]

return UIAnimationManager

-- @module GetTime
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2018.8.30

require "CBase"
require "CloudConsts"
require "LogUtil"
require "Consts"

local jsonex = require "jsonex"
local TAG = "GetTime"

GetTime = CBase:new{ MY_TOPIC="get_time" }

function GetTime:new(o)
    o = o or CBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function GetTime:name()
    return self.MY_TOPIC
end

function GetTime:handle( object )

    local r = false
    if (not object) then
        return r
    end

    --LogUtil.d(TAG,TAG.." handle now")
    r = true
    self:sendGetTime()

    return r
end

function GetTime:sendGetTime(lastReboot)
    local topic = string.format("%s/%s",MyUtils.getUserName(),self:name())

    local msg = {}
    msg[CloudConsts.TIMESTAMP] = os.time()
    local myContent = {}
    
    t = 0
    if lastReboot then
        t = lastReboot
    end
    myContent["last_reboot"]=t

    msg[CloudConsts.CONTENT]=myContent


    MQTTManager.publish(topic,jsonex.encode(msg))
end          

        
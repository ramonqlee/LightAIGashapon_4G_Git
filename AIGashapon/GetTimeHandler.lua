
-- @module GetTimeHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "CloudBaseHandler"
require "CloudConsts"
require "LogUtil"
require "Consts"

local TAG = "GetTimeHandler"

GetTimeHandler = CloudBaseHandler:new{MY_TOPIC="get_time"}

function GetTimeHandler:new (o)
    o = o or CloudBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function GetTimeHandler:name()
    return self.MY_TOPIC
end

function GetTimeHandler:handle( object )

    local r = false
    if (not object) then
        return r
    end

    --LogUtil.d(TAG,TAG.." handle now")
    r = true
    self:sendGetTime()

    return r
end

function GetTimeHandler:sendGetTime(lastReboot)
    local topic = string.format("%s/%s",Consts.getUserName(),self:name())

    local msg = {}
    msg[CloudConsts.TIMESTAMP] = os.time()
    local myContent = {}
    
    t = 0
    if lastReboot then
        t = lastReboot
    end
    myContent["last_reboot"]=t

    msg[CloudConsts.CONTENT]=myContent


    MQTTManager.publish(topic,json.encode(msg))
end          


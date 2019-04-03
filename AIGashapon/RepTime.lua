
-- @module RepTime
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.21
-- tested 2018.8.30

require "CBase"
require "LogUtil"
require "misc"
local jsonex = require "jsonex"
local SYNC_TIME_OUT_IN_SEC = 10

local TAG = "RepTime"

RepTime = CBase:new{
    mServerTimestamp=0,
    MY_TOPIC="reply_time"
}

function RepTime:new(o)
    o = o or CBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function RepTime:name()
    return self.MY_TOPIC
end

-- replyTimeJsonStr = [[
-- {
--     "topic": "1000001/reply_time",
--     "payload": {
--         "timestamp": 1500000009,
--         "content": {
--             "cts": 1400000001
--         }
--     }
-- }
-- ]]
function RepTime:handleContent( timestampInSec,content )
    local r = false
    -- 如果时间小于0或者发送超过了一定时间了，则忽略这次的时间同步
    local cts = content[CloudConsts.CTS]
     if not timestampInSec or timestampInSec<=0 or not cts or cts<=0 then
        LogUtil.d(TAG," illegal content or timestamp,handleContent return")
        return r
    end

    local timeDiff = cts-timestampInSec
    if timeDiff < 0 then
        timeDiff = -timeDiff
    end

    if timeDiff>=SYNC_TIME_OUT_IN_SEC then
        LogUtil.d(TAG," ignore too long timeSync,timeDiff = "..timeDiff)
        return r
    end

    r = true
    self.mServerTimestamp = timestampInSec
    -- 设置系统时间
    ntpTime=os.date("*t",timestampInSec)
    misc.setClock(ntpTime)
    LogUtil.d(TAG," timeSync ntpTime="..jsonex.encode(ntpTime).." changed to now ="..jsonex.encode(os.date("*t",os.time())))

    if not Consts.LAST_REBOOT then
        Consts.LAST_REBOOT = timestampInSec
    end

    return r
end   

                  
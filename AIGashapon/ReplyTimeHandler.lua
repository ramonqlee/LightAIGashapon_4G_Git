
-- @module ReplyTimeHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.21
-- tested 2017.12.26

require "CloudBaseHandler"
require "CloudConsts"
require "LogUtil"
require "misc"
local json = require "jsonex"
-- module(...,package.seeall)

local TAG = "ReplyTimeHandler"

ReplyTimeHandler = CloudBaseHandler:new{
mServerTimestamp=0,
MY_TOPIC="reply_time",
TIME_OUT_IN_MILLS = 10 * 1000
}

function ReplyTimeHandler:new (o)
    o = o or CloudBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReplyTimeHandler:name()
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
function ReplyTimeHandler:handleContent( timestampInSec,content )
    local r = false
    if (timestampInSec<=0) then
        LogUtil.d(TAG," illegal content or timestamp,handleContent return")
        return r
    end

    r = true

    if Consts.timeSynced then
        LogUtil.d(TAG," timeSynced ignore reply_time")
        return true
    end

    self.mServerTimestamp = timestampInSec

    -- 设置系统时间
    ntpTime=os.date("*t",timestampInSec)

    -- 比对差多少秒
    local offset = os.time() - timestampInSec
    if offset < 0 then
        offset = -offset
    end

    if offset > Consts.MIN_TIME_SYNC_OFFSET then
        misc.setClock(ntpTime)
        LogUtil.d(TAG," timeSync ntpTime="..jsonex.encode(ntpTime).." changed to now ="..jsonex.encode(os.date("*t",os.time())))
    else
        if Consts.gTimerId and sys.timer_is_active(Consts.gTimerId) then
            sys.timer_stop(Consts.gTimerId)
            Consts.timeSynced = true
            Consts.LAST_REBOOT = timestampInSec
            LogUtil.d(TAG," timeSync finished")
        end
    end

    return r
end                     
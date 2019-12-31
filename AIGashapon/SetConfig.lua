
-- @module SetConfig
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2018.8.30

require "CloudConsts"
require "sys"
require "CBase"
require "Config"
require "LogUtil"
require "MQTTReplyMgr"
require "RepConfig"
require "UartMgr"
require "MyUtils"
require "UARTShutDown"

local TAG = "SetConfig"

local STATE_INIT = "INIT"
local CHECK_INTERVAL_IN_SEC = 60--检查重启的时间间隔
local rebootTimer
local previousInitSn

local rebootTimeInSec
local shutdownTimeInSec

local function formTimeWithHourMin( timeStr )
    local ONE_HOUR_IN_SEC = 60*60
    local ONE_DAY_IN_SEC = 24*ONE_HOUR_IN_SEC

    if not timeStr or 0 == #timeStr then
        return 0
    end

    local timeTab = MyUtils.StringSplit(timeStr,":")
    local tabLen = MyUtils.getTableLen(timeTab)

    -- 形如"100hour"的支持
    if 1 == tabLen then
        local r = os.time()
        r = r + tonumber(timeTab[1])*ONE_HOUR_IN_SEC
        return r
    end

    -- 形如"7：30"的支持
    if 2 == tabLen then
        local time = misc.getClock()
        return os.time({year =time.year, month = time.month, day =time.day, hour =tonumber(timeTab[1]), min =tonumber(timeTab[2])})
    end

    -- 形如"100:7:30"(10day 7:30)
    if 3 == tabLen  then
        local time = misc.getClock()
        local r = os.time({year =time.year, month = time.month, day =time.day, hour =tonumber(timeTab[2]), min =tonumber(timeTab[3])})
        r = r + tonumber(timeTab[1])*ONE_DAY_IN_SEC
        return r
    end

    -- 形如"2018:12:21:7:30"(2018/12/21 7:30)
    if 5 == tabLen  then
        return os.time({year =tonumber(timeTab[1]), month = tonumber(timeTab[2]), day =tonumber(timeTab[3]), hour =tonumber(timeTab[4]), min =tonumber(timeTab[5])})
    end

    return os.time()
end


SetConfig = CBase:new{
    MY_TOPIC = "set_config"
}


function SetConfig:new(o)
    o = o or CBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function SetConfig:name()
    return self.MY_TOPIC
end


-- testPushStr = [[
-- {
--     "topic": "1000001/set_config",
--     "payload": {
--         "timestamp": "1400000000",
--         "content": {
--             "sn": "19291322",
--             "state": "TEST",
--             "node_name": "北京国贸三期店",
--             "reboot_schedule": "05:00",
--             "price": 1000
--         }
--     }
-- }
-- ]]
function SetConfig:handleContent( content )
	local r = false
 	if not content then
 		return
 	end

 	local state = content[CloudConsts.STATE]
 	local sn = content[CloudConsts.SN]
 	if not state or not sn then
 		return r
 	end
    
    local haltTimeTemp = content[CloudConsts.HALT_SCHEDULE]--关机时间
    local rebootTime = content[CloudConsts.REBOOT_SCHEDULE]--开机时间

    --TOOD 加入误操作机制
    --如果收到的关机时间已经过了，则忽略
    if not rebootTime or not haltTimeTemp or 0==#rebootTime or 0==#haltTimeTemp then
        Config.saveValue(CloudConsts.HALT_SCHEDULE,"")
        Config.saveValue(CloudConsts.REBOOT_SCHEDULE,"")
    else
        local tempTime = formTimeWithHourMin(haltTimeTemp)
        if tempTime > os.time() then
            local haltTime = haltTimeTemp

            if rebootTime or haltTime then
                --更新定时开关机策略
                Config.saveValue(CloudConsts.HALT_SCHEDULE,haltTime)
                Config.saveValue(CloudConsts.REBOOT_SCHEDULE,rebootTime)

                LogUtil.d(TAG,"rebootTime = "..rebootTime.." haltTime="..haltTime)

                rebootTimeInSec = formTimeWithHourMin(rebootTime)
                shutdownTimeInSec = formTimeWithHourMin(haltTime)
                --理论上开机时间应该在关机时间之后，所以需要处理下
                if rebootTimeInSec < shutdownTimeInSec then
                    --将开机时间推迟到第二天
                    LogUtil.d(TAG," origin rebootTimeInSec= "..rebootTimeInSec)
                    rebootTimeInSec = rebootTimeInSec+24*60*60
                end

                LogUtil.d(TAG,"rebootTimeInSec = "..rebootTimeInSec.." shutdownTimeInSec = "..shutdownTimeInSec.." os.time()="..os.time())

                content["setHaltTime"]=shutdownTimeInSec
                content["setBootTime"]=rebootTimeInSec
            end
        end

    end

    local reply = STATE_INIT ~= state
    if STATE_INIT == state and Consts.REPLY_INIT_CONFIG then 
        reply = true
    end

    if reply then
        MQTTReplyMgr.replyWith(RepConfig.MY_TOPIC,content)
    end

    SetConfig.startRebootSchedule()

 	-- 恢复初始状态
 	if STATE_INIT==state then
        -- 获取最近一次INIT的sn，如果是重复的，则不再发送消息
        if previousInitSn ~= sn then
            previousInitSn = sn

            LogUtil.d(TAG,"state ="..state.." clear nodeId and password")
            MyUtils.clearUserName()
            MyUtils.clearPassword()
            
            MQTTManager.disconnect()
        end
    end
end 

function SetConfig:startRebootSchedule()
    --TODO 在此增加定时开关机功能
    -- 设定一个定时器，每分钟检查一次，是否到了关键时间
    -- 如果到了的话，看是否满足关机的条件
    -- 1. 没有待发送的消息
    -- 2. 没有订单在出货中
    if rebootTimer and sys.timerIsActive(rebootTimer) then
        return
    end

    rebootTimer = sys.timerLoopStart(function()
        LogUtil.d(TAG," checking reboot schedule")

        if MQTTManager.hasMessage() or Deliver.isDelivering() then
            LogUtil.d(TAG," checking reboot schedule,but mqtt has message or is delivering")
            return
        end

        local haltTime = Config.getValue(CloudConsts.HALT_SCHEDULE)
        local rebootTime = Config.getValue(CloudConsts.REBOOT_SCHEDULE)

        if not rebootTime or not haltTime or 0 == #rebootTime or 0 == #haltTime then
            return
        end

        --转换为当前时间
        LogUtil.d(TAG,"rebootTime = "..rebootTime.." haltTime="..haltTime)

        rebootTimeInSec = formTimeWithHourMin(rebootTime)
        shutdownTimeInSec = formTimeWithHourMin(haltTime)
        --理论上开机时间应该在关机时间之后，所以需要处理下
        if rebootTimeInSec < shutdownTimeInSec then
            --将开机时间推迟到第二天
            LogUtil.d(TAG," origin rebootTimeInSec= "..rebootTimeInSec)
            rebootTimeInSec = rebootTimeInSec+24*60*60
        end


        if not shutdownTimeInSec or not rebootTimeInSec or 0==shutdownTimeInSec or 0==rebootTimeInSec then
            return
        end

        --如果是关机时间，早于开机时间，判断是否需要关机
        if shutdownTimeInSec < rebootTimeInSec then
            if os.time() < shutdownTimeInSec or os.time()> rebootTimeInSec then
                return
            end
        else--如果是关机时间晚于开机时间的，判断是否需要关机
            if os.time()>rebootTimeInSec and os.time()<shutdownTimeInSec then
                return
            end
        end


        --关机，并设定下次开机的时间
        local delay = rebootTimeInSec - shutdownTimeInSec
        if delay < 0 then
            delay = -delay
        end

        local r = UARTShutDown.encode(delay)
        UartMgr.publishMessage(r)
        LogUtil.d(TAG,"......shutdown now....after "..delay.."seconds, it will poweron")
    end,CHECK_INTERVAL_IN_SEC*1000)
end



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
local REBOOT_TIMEOUT = 5*60
local CHECK_INTERVAL_IN_SEC = 60--检查重启的时间间隔
local rebootTime
local haltTime 
local rebootTimer

local function formTimeWithHourMin( timeStr )
    local SPLIT_LEN = 2
    local timeTab = MyUtils.StringSplit(timeStr,":")

    if MyUtils.getTableLen(timeTab) ~= SPLIT_LEN then
        return os.time()
    end

        -- 是否到时间了，关机并设置下次开机的时间
    local time = misc.getClock()
    return os.time({year =time.year, month = time.month, day =time.day, hour =tonumber(timeTab[1]), min =tonumber(timeTab[2])})
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

 	Config.saveValue(CloudConsts.VM_SATE,state)
 	Config.saveValue(CloudConsts.NODE_NAME,content[CloudConsts.NODE_NAME])
 	Config.saveValue(CloudConsts.NODE_PRICE,content[CloudConsts.NODE_PRICE])
 	-- Config.saveValue(CloudConsts.REBOOT_SCHEDULE,content[CloudConsts.REBOOT_SCHEDULE])
    haltTime = content[CloudConsts.HALT_SCHEDULE]--关机时间
    rebootTime = content[CloudConsts.REBOOT_SCHEDULE]--开机时间

    --TOOD 加入误操作机制
    --如果收到的关机时间已经过了5分钟，则忽略
    local rebootTimeInSec = formTimeWithHourMin(haltTime)
    if rebootTimeInSec + REBOOT_TIMEOUT < os.time() then
        haltTime = nil
        rebootTime = nil
        LogUtil.d(TAG,"timeout boot schedule,ignore")
    end
    

    SetConfig.startRebootSchedule()

 	nodeName = Config.getValue(CloudConsts.NODE_NAME)
 	if nodeName then
 		LogUtil.d(TAG,"state ="..state.." node_name="..nodeName)
 	else
 		LogUtil.d(TAG,"nodeName is empty")
 	end

 	-- print(RepConfig.MY_TOPIC)
 	MQTTReplyMgr.replyWith(RepConfig.MY_TOPIC,content)

 	-- 恢复初始状态
 	if STATE_INIT==state then
    	LogUtil.d(TAG,"state ="..state.." clear nodeId and password")
        MyUtils.clearUserName()
        MyUtils.clearPassword()
        
    	MQTTManager.disconnect()
    	return
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

        if not rebootTime or not haltTime then
            return
        end

        LogUtil.d(TAG,"rebootTime = "..rebootTime.." haltTime="..haltTime)

        local rebootTimeInSec = formTimeWithHourMin(rebootTime)
        local shutdownTimeInSec = formTimeWithHourMin(haltTime)
        --理论上开机时间应该在关机时间之后，所以需要处理下
        if rebootTimeInSec < shutdownTimeInSec then
            --将开机时间推迟到第二天
            LogUtil.d(TAG," origin rebootTimeInSec= "..rebootTimeInSec)
            rebootTimeInSec = rebootTimeInSec+24*60*60
        end

        LogUtil.d(TAG,"rebootTimeInSec = "..rebootTimeInSec.." shutdownTimeInSec = "..shutdownTimeInSec.." os.time()="..os.time())
        if shutdownTimeInSec > os.time() then
            return
        end

        --关机，并设定下次开机的时间
        local delay = shutdownTimeInSec-rebootTimeInSec
        if delay < 0 then
            delay = -delay
        end

        local r = UARTShutDown.encode(delay)
        UartMgr.publishMessage(r)
        LogUtil.d(TAG,"......shutdown now....after "..delay.."seconds, it will poweron")
    end,CHECK_INTERVAL_IN_SEC*1000)
end


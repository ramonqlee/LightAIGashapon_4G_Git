-- @module ScanQrCode
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2018.5.11
-- tested 2018.5.11

require "Consts"
require "LogUtil"
require "UartMgr"
require "UARTPlayAudio"
require "CloudConsts"
require "CBase"


local TAG = "ScanQrCode"

local lastPurchaseTime=0
local lastLocation=1

ScanQrCode = CBase:new{
    MY_TOPIC = "event_qr_scaned"
}


function ScanQrCode:lastPurchaseTime()
    return lastPurchaseTime
end

function ScanQrCode:lastLocation()
    return lastLocation
end

function ScanQrCode:new(o)
    o = o or CBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function ScanQrCode:name()
    return self.MY_TOPIC
end

function ScanQrCode:handleContent( content )
 	-- TODO to be coded
    -- 出货
    -- 监听出货情况
    -- 超时未出货，上传超时错误

    local r = false
    if (not content) then
        return
    end

    -- 1. 合法性校验：字段全，没有超时，如果超时了，则直接发送出货日志，标志位超时
    -- 2. 收到出货通知后的回应
    -- 3. 否则开锁，然后启动定时器监控超时；
    -- 4. 超时后，上传超时出货日志；
    -- 5. 收到出货成功后，删除超时等待队列中的订单信息，然后上传出货日志
    local device_seq = content[CloudConsts.DEVICE_SEQ]
    local location = content[CloudConsts.LOCATION]
    local sn = content[CloudConsts.SN]
    if not device_seq or not location or not sn then 
        LogUtil.d(TAG,TAG.." oopse,missing key")
        return
    end

    lastLocation = location
    lastPurchaseTime = os.time()

    --播放扫码声音
    local r = UARTPlayAudio.encode(UARTPlayAudio.SCAN_AUDIO)
	UartMgr.publishMessage(r)
end   


    
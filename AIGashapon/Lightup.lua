
-- @module Lightup
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 

require "LogUtil"
require "UartMgr"
require "jsonex"
require "CloudConsts"
require "UARTBroadcast"
require "CBase"

local lastLightUpTime = 0

local TAG = "Lightup"
Lightup = CBase:new{
    MY_TOPIC = "light_up",
}

function Lightup:new (o)
    o = o or CBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function Lightup:name()
    return self.MY_TOPIC
end

function Lightup:isLightuping()
    return (os.time()-lastLightUpTime<Consts.TWINKLE_TIME_DELAY)
end

-- testPushStr = [[
-- {
--     "topic": "1000001/light_up",
--     "payload": {
--         "timestamp": "1400000000",
--         "content": {
		-- “device_seq”: “1”, //
		-- “location”: “1”, //目前是1-3，对应一个板子挂的三台实际扭蛋机
		-- “duration”: “5”，//闪灯持续时间，单位秒，如果未收到关闭灯光指令，则按照此数值持续
		-- “sn”: “389291”,
--         }
--     }
-- }
-- ]]
function Lightup:handleContent( content )
	LogUtil.d(TAG,TAG.." handleContent,content "..jsonex.encode(content))

	local r = false
 	if (not content) then
 		return
 	end

	local device_seq = content[CloudConsts.DEVICE_SEQ]
	local location = content[CloudConsts.LOCATION]
	local duration = content[CloudConsts.DURATION]

	if not device_seq or not location or not duration then 
		return
	end

	addr=nil
	if "string" == type(device_seq) then
        addr = string.fromHex(device_seq)
	elseif "number"==type(device_seq) then
        addr = string.format("%2X",device_seq)
    end

    if not addr or #addr<3 then 
    	LogUtil.d(TAG," illegal addr,return")
    	return
    end

	if "string" == type(duration) then
        duration = tonumber(duration,10)
    end

    if "string" == type(location) then
        location = tonumber(location,10)
    end

    if not device_seq or not location or not duration then 
		return
	end

 	-- 闪灯协议
	local msgArray = {}
	local v = {}
	v["id"] = addr
	v["group"] = pack.pack("b",location)
	v["color"] = pack.pack("b",2)--1bye0--red;1-green
	v["time"] = pack.pack(">h",duration*2)--0.5s
	msgArray[#msgArray+1]=v

	r = UARTBroadcast.encode(msgArray)
	UartMgr.publishMessage(r)

	lastLightUpTime = os.time()
end  


 
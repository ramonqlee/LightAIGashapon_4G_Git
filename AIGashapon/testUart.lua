--- 模块功能：testAdc
-- @module test
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.1.3
-- @describe 每隔5s发送0x01,0x20

-- module(...,package.seeall)
require "sys"
require"clib"
require"pm"
require"utils"
require "LogUtil"
require "UartMgr"
require "UARTBroadcast"
require "UARTBoardInfo"
require "UARTGetAllInfo"
require "UARTControlInd"
require "UARTStatRep"
require "MQTTManager"


TAG="TestUart"

function openLockCallback( addr, status )
	if addr then
		--LogUtil.d(TAG,"openLockCallback addr ="..addr)
	end

	s1,s2=UARTStatRep.getStates(1)
	if s1 and s2 then
		--LogUtil.d(TAG,"openLockCallback group1 s1 ="..s1.." s2 = "..s2)
	else
		--LogUtil.d(TAG,"openLockCallback group1 s1,s2 unknown")
	end

	s1,s2=UARTStatRep.getStates(2)
	if s1 and s2 then
		--LogUtil.d(TAG,"openLockCallback group2 s1 ="..s1.." s2 = "..s2)
	else
		--LogUtil.d(TAG,"openLockCallback group2 s1,s2 unknown")
	end

	s1,s2=UARTStatRep.getStates(3)
	if s1 and s2 then
		--LogUtil.d(TAG,"openLockCallback group3 s1 ="..s1.." s2 = "..s2)
	else
		--LogUtil.d(TAG,"openLockCallback group3 s1,s2 unknown")
	end
end

function allInfoCallback( ids )
	-- 获取第一个从板id，进行开锁操作
	addr=""
	for _,v in ipairs(UARTAllInfoRep.getAllBoardIds(true)) do
		LogUtil.d(TAG,"parse UARTAllInfoRep allId val = "..v)
		if v then
			addr = v
			break
		end
	end

	if not addr or 0 == #addr then
		--LogUtil.d(TAG,"illgeal addr,return")
		return
	end

	--LogUtil.d(TAG,"addr = "..addr)
-- 开锁
-- addr = pack.pack("b3",0x00,0x00,0x06) 
-- loc = 1 
-- timeoutInSec =2
-- UARTStatRep.setCallback(openLockCallback)
-- r = UARTControlInd.encode(addr,loc,timeoutInSec)

-- UartMgr.publishMessage(r)
end
--[[
如果需要打开“串口发送数据完成后，通过异步消息通知”的功能，则按照如下配置
local function txdone()
	print("txdone")
end
uart.setup(UART_ID,115200,8,uart.PAR_NONE,uart.STOP_1,nil,1)
uart.on (UART_ID, "sent", txdone)
]]

-- 		-- 闪灯协议
	-- msgArray = {}
	-- v = {}
	-- v["id"] = pack.pack("b3",0x00,0x00,0x6E)--3 bytes
	-- v["group"] = pack.pack("b",1)--1byte
	-- v["color"] = pack.pack("b",2)--1bye
	-- v["time"] = pack.pack(">h",10)
	-- msgArray[#msgArray+1]=v

	-- r = UARTLightup.encode(msgArray)
	-- UartMgr.publishMessage(r)

sys.timerStart(function()
		LogUtil.d(TAG,"start to retry identify slaves")
		sys.taskInit(function()
			--首先初始化本地环境，然后成功后，启动mqtt
			UartMgr.init(Consts.UART_ID,Consts.baudRate)
			--获取所有板子id
			UartMgr.initSlaves(allInfoCallback,true)    
		end)

	end,125*1000)


-- r = UARTBoardInfo.encode() 
-- r = UARTGetAllInfo.encode()--获取所有板子id
-- UARTAllInfoRep.setCallback(allInfoCallback)

-- 开锁
-- addr = pack.pack("b3",0x00,0x00,0x02) 
-- loc = 1 
-- timeoutInSec = 60
-- callback = nil
-- UARTStatRep.setCallback = callback
-- r = UARTControlInd.encode(addr,loc,timeoutInSec)
-- UartMgr.publishMessage(r)

-- --开另外一个锁
-- addr = pack.pack("b3",0x00,0x00,0x03) 
-- r = UARTControlInd.encode(addr,loc,timeoutInSec)
-- UartMgr.publishMessage(r)

-- FIXME 测试用
-- sys.taskInit(MQTTManager.startmqtt)

-- sys.taskInit(function()
-- 	while true do
-- 		UartMgr.init(Consts.UART_ID,Consts.baudRate)
-- 		local addr = pack.pack("b3",0x00,0x00,0x02) 
-- 		local loc = 1 
-- 		local timeoutInSec =120
-- 		callback = nil
-- 		UARTStatRep.setCallback = callback
-- 	-- 发送开锁报文
-- 		r = UARTControlInd.encode(addr,loc,timeoutInSec)
--  		UartMgr.publishMessage(r)

--  		--发送另外一个
--  		addr = pack.pack("b3",0x00,0x00,0x03) 
-- 		r = UARTControlInd.encode(addr,loc,timeoutInSec)
-- 		UartMgr.publishMessage(r)

-- 		-- sys.wait(30000)--两次写入消息之间停留一段时间
-- 		break
-- 	end
-- 	end)  


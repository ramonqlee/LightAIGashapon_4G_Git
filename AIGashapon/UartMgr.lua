
-- @module UartMgr
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.27
-- @tested 2018.01.28

require "LogUtil"
if Consts.DEVICE_ENV then
	require "sys"
end

require "UARTStatusReport"
require "UARTAllInfoReport"
require "UARTBoardInfo"
require "UARTGetAllInfo"

local TAG = "UartMgr"
UartMgr={
devicePath=nil,
toWriteMessages={}
}


local protocalStack = {}--串口协议栈

local function initProtocalStack(clear)
	if clear then
		protocalStack = {}
		return
	end

	if protocalStack and #protocalStack>0 then
		return 
	end

	if not protocalStack then
		protocalStack = {}
	end

	-- TODO 在此注册串口处理协议
	protocalStack[#protocalStack+1]=UARTStatusReport.handle
	protocalStack[#protocalStack+1]=UARTAllInfoReport.handle
	protocalStack[#protocalStack+1]=UARTBoardInfo.handle
	
end


local function dispatch( data )
	initProtocalStack(false)

	for _,handler in pairs(protocalStack) do
		-- TODO 处理协议数据
		-- --LogUtil.d(TAG,"try indexed "..i.." handler")
		if handler then
			pos = handler(data)
			if pos and pos>=0 then
				-- --LogUtil.d(TAG,"find hander")
				return pos
			end
		end
	end

	initProtocalStack(true)
	return nil
end 

-- 计算可能存在的帧数
function startFrame( bins )
	pos = 0
	for i=1,#bins do
		if UARTUtils.RCV == string.byte(bins,i) then
			return i
		end
	end
	--LogUtil.d(TAG,"find startPos and count = "..c)
	return pos
end

function countFrame( bins )
	c = 0
	for i=1,#bins do
		if UARTUtils.RCV == string.byte(bins,i) then
			c = c+1
		end
	end
	--LogUtil.d(TAG,"find startPos and count = "..c)
	return c
end

--[[
函数名：write
功能  ：通过串口发送数据
参数  ：
		s：要发送的数据
返回值：无
]]
function uart_write(s)
	if not s or 0 == #s then
		return
	end
	uart.write(UartMgr.devicePath,s)
	-- LogUtil.d(TAG,"uart write = "..string.tohex(s))
end

local readDataCache=""
-- uart读取函数
function  uart_read()
	-- TODO 待根据具体的协议数据，进行解析
	local data = ""
	--底层core中，串口收到数据时：
	--如果接收缓冲区为空，则会以中断方式通知Lua脚本收到了新数据；
	--如果接收缓冲器不为空，则不会通知Lua脚本
	--所以Lua脚本中收到中断读串口数据时，每次都要把接收缓冲区中的数据全部读出，这样才能保证底层core中的新数据中断上来，此read函数中的while语句中就保证了这一点
	
	local MIN_CACHE_SIZE=100
	local MAX_CACHE_SIZE=256
	while true do	
		-- 将协议数据进行缓存，然后逐步处理	
		LogUtil.d(TAG,"uart start to read from uart")
		data = uart.read(UartMgr.devicePath,"*l")
		if not data or string.len(data) == 0 then 
			LogUtil.d(TAG,"empty data")
			break
		end
		
		LogUtil.d(TAG,"uart read = "..string.tohex(data))
		readDataCache = readDataCache..data

		-- 循环处理数据，防止出现无法处理的情况，导致阻塞
		while true do
			--打开下面的打印会耗时
			if readDataCache then
				LogUtil.d(TAG,"uart before dispatch = "..string.tohex(readDataCache))
			end
			
			endPos,startPos = dispatch(readDataCache)

			-- 跳过处理过的数据
			if endPos and endPos > 0 then
				readDataCache = string.sub(readDataCache,endPos+1)
				
				if readDataCache then
					LogUtil.d(TAG,"uart after dispatch = "..string.tohex(readDataCache))
				end
			else
				--上面的数据没有匹配的处理器
				--1. 有多个rcv，尝试跳过第一个，因为可能第一个有可能数据不合法
				--2. 不多于1个rcv，保留下数据，等待后续的处理
				if countFrame(readDataCache)>1 then
					readDataCache = string.sub(readDataCache,startFrame(readDataCache)+1)
					if readDataCache then
						LogUtil.d(TAG,"uart jump to next frame readDataCache = "..string.tohex(readDataCache))
					end
				else
					if readDataCache then
						LogUtil.d(TAG,"uart wait for new stream readDataCache = "..string.tohex(readDataCache))
					end
					break
				end
			end

		end
	end
end



-- 初始化串口
function UartMgr.init( devicePath, baudRate)
	if UartMgr.devicePath and "number" == type(UartMgr.devicePath) then
		-- LogUtil.d(TAG,"UartMgr.inited devicePath ="..devicePath.." baudRate = "..baudRate)
		return
	end

	LogUtil.d(TAG,"UartMgr.init devicePath ="..devicePath.." baudRate = "..baudRate)
	if not Consts.DEVICE_ENV then
		--LogUtil.d(TAG,"not device,UartMgr.init and return")
	end

	if not devicePath or not baudRate then
		--LogUtil.d(TAG,"empty devicePath or baudRate and return")
		return
	end

 	--保持系统处于唤醒状态，此处只是为了测试需要，所以此模块没有地方调用pm.sleep("test")休眠，不会进入低功耗休眠状态
	--在开发“要求功耗低”的项目时，一定要想办法保证pm.wake("test")后，在不需要串口时调用pm.sleep("test")
	UartMgr.devicePath = devicePath
	-- pm.wake("testUart")
	--注册串口的数据接收函数，串口收到数据后，会以中断方式，调用read接口读取数据
	uart.on(UartMgr.devicePath, "receive", uart_read)
	--配置并且打开串口
	uart.setup(UartMgr.devicePath,baudRate,8,uart.PAR_NONE,uart.STOP_1)

	-- 发送获取从板id的指令，初始化系统的一部分
	LogUtil.d(TAG,"UartMgr.init done")
end 

function UartMgr.publishMessage( msg )
	UartMgr.toWriteMessages[#UartMgr.toWriteMessages+1]=msg
end

function UartMgr.close( devicePath )
	if not Consts.DEVICE_ENV then
		--LogUtil.d(TAG,"not device,UartMgr.close and return")
	end

	if not devicePath then
		return
	end

	-- pm.sleep("test")
	-- uart.close(devicePath)
end

function UartMgr.initSlaves( callback ,retry)

	if not retry then
		ids = UARTAllInfoReport.getAllBoardIds(false)
		if ids and #ids > 0 then
			LogUtil.d(TAG,"UartMgr.initSlaves done,size = "..#ids)
			return
		end 
	end
	LogUtil.d(TAG,"UartMgr.initSlaves")

	r = UARTGetAllInfo.encode()--获取所有板子id
	if callback then
		UARTAllInfoReport.setCallback(callback)
	else
		UARTAllInfoReport.setCallback(function( ids )
			addr=""
			ids = UARTAllInfoReport.getAllBoardIds(true)
			for _,v in pairs(ids) do
				if v then
					addr = addr.." "..string.fromhex(v)
				end
			end

			if addr or #addr>0 then
				LogUtil.d(TAG,"UartMgr.initSlaves SlaveIDChain = "..addr)
				return
			end
		end)
	end

	UartMgr.publishMessage(r)
end

sys.taskInit(function()
	while true do
		UartMgr.init(Consts.UART_ID,Consts.baudRate)
		-- 发送消息
		for _,msg in pairs(UartMgr.toWriteMessages) do
			uart_write(msg)
		end
		UartMgr.toWriteMessages = {}

		sys.wait(Consts.WAIT_UART_INTERVAL)--两次写入消息之间停留一段时间
	end
end)      



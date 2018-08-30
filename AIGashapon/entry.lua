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
require"utils"
require "LogUtil"
require "UartMgr"
require "MQTTManager"
require "UARTBroadcastLightup"

local TAG="Entry"
local timerId=nil

entry = {}
local mqttStarted=false
local TWINKLE_POS_1 = 1
local TWINKLE_POS_2 = 2
local TWINKLE_POS_3 = 3
local MAX_TWINKLE	= TWINKLE_POS_3
local nextTwinklePos=TWINKLE_POS_1

local RED  = 0
local BLUE = 1
local BOTH = 2
local MAX_COLOR = BLUE
local topNextColor = RED
local middleNextColor = BLUE
local bottomNextColor = RED

local MAX_RETRY_COUNT = 3
local RETRY_BOARD_COUNT = 1--识别的数量小于这个，就重试
local boardIdentified = 0
local retryCount = 0

function startTimedTask()
    if timedTaskId and sys.timerIsActive(timedTaskId) then
        LogUtil.d(TAG," startTimedTask running,return")
        return
    end

    timedTaskId = sys.timerLoopStart(function()
            if MQTTManager.hasMessage() then
            	return
            end

            sys.taskInit(function()
				checkTask()
				--wait until task finished
				while Task.isRunning() do
					sys.wait(Consts.TASK_WAIT_IN_MS)
				end

            	checkUpdate()
			end)
            
            LogUtil.d(TAG,"publish message queue is empty,startTimedTask")
        end,Consts.TIMED_TASK_INTERVAL_MS)
end

-- 自动升级检测
function checkUpdate()
    if DeliverHandler.isDelivering() then
        LogUtil.d(TAG,TAG.." DeliverHandler.isDelivering or Lightup.isLightuping,delay update")
        return
    end

    if update.isDownloading() then
        LogUtil.d(TAG,"checkUpdating,return")
        return 
    end

    update.run() -- 检测是否有更新包
    LogUtil.d(TAG,"start checkUpdate now")
end


--任务检测
function checkTask()
    if DeliverHandler.isDelivering() then
        LogUtil.d(TAG,TAG.." DeliverHandler.isDelivering or Lightup.isLightuping,delay taskCheck")
        return
    end
    
    if Task.isRunning() then 
		LogUtil.d(TAG,"Task.isRunning,return")
		return
    end

    Task.getTask()               -- 检测是否有新任务 
    LogUtil.d(TAG,"start checkTask now")
end

function allInfoCallback( ids )
	if ids and #ids > 0 then
		boardIdentified = #ids
	end

	--取消定时器 
	if timerId and  sys.timerIsActive(timerId) then
		sys.timer_stop(timerId)
		LogUtil.d(TAG,"init slaves done")
	end 

	if not mqttStarted then
		mqttStarted = true
		sys.taskInit(MQTTManager.startmqtt)
	end

end

function entry.retryIdentify()
	-- 超过了最大的重试次数
	retryCount = retryCount + 1
	if retryCount > MAX_RETRY_COUNT then
		LogUtil.d(TAG,"init slaves ,reach retry count ="..MAX_RETRY_COUNT)
		return
	end

	if timerId and  sys.timerIsActive(timerId) then
		sys.timer_stop(timerId)
	end 

	-- 发起识别请求，并进行超时处理
	timerId=sys.timerStart(function()
		LogUtil.d(TAG,"start to retry identify slaves")
		sys.taskInit(function()
			--首先初始化本地环境，然后成功后，启动mqtt
			UartMgr.init(Consts.UART_ID,Consts.baudRate)
			--获取所有板子id
			UartMgr.initSlaves(allInfoCallback,true)    
		end)

	end,5*1000)


	sys.timerStart(function()
		LogUtil.d(TAG,"retry timeout in retrieving slaves")
		if timerId and  sys.timerIsActive(timerId) then
			sys.timer_stop(timerId)
		end

		if boardIdentified < RETRY_BOARD_COUNT  then
			entry.retryIdentify()
		end

	end,180*1000)  

end


function entry.run()
	startTimedTask()
	-- 启动一个延时定时器, 获取板子id
	timerId=sys.timerStart(function()
		LogUtil.d(TAG,"start to retrieve slaves")
		sys.taskInit(function()
			--首先初始化本地环境，然后成功后，启动mqtt
			UartMgr.init(Consts.UART_ID,Consts.baudRate)
			--获取所有板子id
			UartMgr.initSlaves(allInfoCallback,false)    
		end)

	end,10*1000)

	
	-- 启动一个延时定时器，防止没有回调时无法正常启动
	sys.timerStart(function()
		LogUtil.d(TAG,"start after timeout in retrieving slaves")
		if  boardIdentified < RETRY_BOARD_COUNT then 
			entry.retryIdentify()
		end

		if not mqttStarted then
			mqttStarted = true
			sys.taskInit(MQTTManager.startmqtt)
		end

		LogUtil.d(TAG,"start twinkle task")
		entry.startTwinkleTask()

	end,Consts.TEST_MODE and 15*1000 or 180*1000)  

end


-- 让灯闪起来
-- addrs 地址数组
-- pos 扭蛋机位置，目前取值1，2
-- time 闪灯次数，每次?ms
function entry.twinkle( addrs,pos,times )
	-- 闪灯协议
	local msgArray = {}

	-- bds = UARTAllInfoReport.getAllBoardIds(true)
	local nextColor = topNextColor
	if TWINKLE_POS_1 == pos then
		nextColor = topNextColor
	elseif TWINKLE_POS_2 == pos then
		nextColor = middleNextColor
	else
		nextColor = bottomNextColor
	end

	if addrs and #addrs >0 then
		for _,addr in pairs(addrs) do
			-- device["seq"]=v
			item = {}
			item["id"] = string.fromhex(addr)
			item["group"] = pack.pack("b",pos)--1byte
			item["color"] = pack.pack("b",nextColor)--1bye
			item["time"] = pack.pack(">h",times)
			msgArray[#msgArray+1]=item
		end
	end

	if 0 == #msgArray then
		return
	end

	r = UARTBroadcastLightup.encode(msgArray)
	UartMgr.publishMessage(r)      
	
	-- 切换颜色
	nextColor = nextColor + 1
	if nextColor > MAX_COLOR then
		nextColor = RED
	end
	
	if TWINKLE_POS_1 == pos then
		topNextColor = nextColor
	elseif TWINKLE_POS_2 == pos then
		middleNextColor = nextColor
	else
		bottomNextColor = nextColor
	end
end

function entry.startTwinkleTask( )
	-- 启动一个定时器，负责闪灯，当出货时停止闪灯
	sys.timerLoopStart(function()
			--出货中，不集体闪灯
			if DeliverHandler.isDelivering() or Lightup.isLightuping() then
				LogUtil.d(TAG,TAG.." DeliverHandler.isDelivering or Lightup.isLightuping")
				return
			end

			addrs = UARTAllInfoReport.getAllBoardIds(true)

			if not addrs or 0 == #addrs then
				-- LogUtil.d(TAG,TAG.." no slaves found,ignore twinkle")
				return
			end

			-- LogUtil.d(TAG,TAG.." twinkle pos = "..nextTwinklePos)

            entry.twinkle( addrs,nextTwinklePos,Consts.TWINKLE_TIME )

            --切换闪灯位置
            nextTwinklePos = nextTwinklePos + 1
            
            --是否有第三层，如果没有，直接跳到第一层
            local thirdLevelKey = Config.getValue(CloudConsts.THIRD_LEVEL_KEY)
            local thirdLevelExist = CloudConsts.THIRD_LEVEL_KEY==thirdLevelKey
            if not thirdLevelExist and TWINKLE_POS_3 == nextTwinklePos then
            	nextTwinklePos = TWINKLE_POS_1
            end

			if nextTwinklePos > MAX_TWINKLE then
				nextTwinklePos = TWINKLE_POS_1
			end

        end,Consts.TWINKLE_INTERVAL)
end




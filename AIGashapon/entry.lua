--- 模块功能：testAdc
-- @module test
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2018.1.3
-- @describe 每隔5s发送0x01,0x20

require "clib"
require "utils"
require "ntp"
require "mywd"
require "Consts"
require "LogUtil"
require "UartMgr"
require "update"
require "Config"
require "Task"
require "Deliver"
require "MQTTManager"
require "Lightup"
require "UARTLightup"
require "MyUtils"
require "ConstsPrivate"
require "UARTAllInfoRep"


local TAG="Entry"
local timerId=nil
local keepAliveTimer
-- local retryIdentifyTimerId=nil
local candidateRunTimerId=nil
local timedTaskId = nil
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

local TWINKLE_TYPE_STILL   = 0 --不闪灯
local TWINKLE_TYPE_TWINKLE = 1 --间隔4秒，整行闪灯
local TWINKLE_TYPE_COUNT = 2--twinkle种类的数量，用于防止出现越界的情况

local twinkleTimerId = nil
local twinkleOption = TWINKLE_TYPE_STILL
local allBoardCheckTimer = nil


function startTimedTask()
    if timedTaskId and sys.timerIsActive(timedTaskId) then
        LogUtil.d(TAG," startTimedTask running,return")
        return
    end

    checkUpdate()
    timedTaskId = sys.timerLoopStart(function()
    		checkTwinkleSwitch()
            checkTask()
            checkUpdate()
            
        end,Consts.TIMED_TASK_INTERVAL_MS)
end

function checkTwinkleSwitch()
	local nodeId = MyUtils.getUserName(false)
    if not nodeId or 0 == #nodeId then
        LogUtil.d(TAG,"checkTwinkleSwitch return for unbound node")
        return
    end 

	--TODO 待根据后台开关，设定是否允许闪灯
	url = string.format(ConstsPrivate.MQTT_TWINKLE_URL_FORMATTER,nodeId)
    LogUtil.d(TAG,"url = "..url)
    http.request("GET",url,nil,nil,nil,nil,function(result,prompt,head,body )
        if result and body then
            -- LogUtil.d(TAG,"http config body="..body)
            bodyJson = jsonex.decode(body)

            if not bodyJson then
                return
            end

            twinkleOption = bodyJson['twinkleOption']
            if not twinkleOption then
				twinkleOption = TWINKLE_TYPE_STILL
            end

            twinkleOption = twinkleOption%TWINKLE_TYPE_COUNT
        end
        
    end)
end

-- 自动升级检测
function checkUpdate()
    update.request() -- 检测是否有更新包
end

--任务检测
function checkTask()
    Task.getTask()               -- 检测是否有新任务 
end

function allInfoCallback( boardIDArray )
	boardIdentified = MyUtils.getTableLen(boardIDArray)
	
	--是否有无效的id
	if UARTAllInfoRep.hasIds("000000") then
		boardIdentified = 0
	end

	--取消定时器 
	if timerId and sys.timerIsActive(timerId) then
		sys.timerStop(timerId)
		timerId = nil
		LogUtil.d(TAG,"init slaves done")
	end 

	if not MQTTManager.mqttStarted() then
		sys.taskInit(MQTTManager.startmqtt)
	end

end

-- 让灯闪起来
-- addrs 地址数组
-- pos 扭蛋机位置，目前取值1，2
-- time 闪灯次数，每次?ms
function twinkle( addrs,pos,times )
	-- 闪灯协议
	local msgArray = {}

	-- bds = UARTAllInfoRep.getAllBoardIds(true)
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
			item["id"] = string.fromHex(addr)
			item["group"] = pack.pack("b",pos)--1byte
			item["color"] = pack.pack("b",nextColor)--1bye
			item["time"] = pack.pack(">h",times)
			msgArray[#msgArray+1]=item
		end
	end

	if 0 == #msgArray then
		return
	end

	r = UARTLightup.encode(msgArray)
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

function startAllBoardCheck()
	if allBoardCheckTimer and sys.timerIsActive(allBoardCheckTimer) then
		LogUtil.d(TAG,"allBoardCheckTimer started")
		return
	end

	allBoardCheckTimer = sys.timerLoopStart(function()
		if boardIdentified >0 or Consts.BOARD_CHECK_COUNT > Consts.MAX_BOARD_CHECK_COUNT then
			if allBoardCheckTimer and sys.timerIsActive(allBoardCheckTimer) then
				sys.timerStop(allBoardCheckTimer)
			end
			LogUtil.d(TAG,"boardIdentified,stop loop check")
			return
		end

		UartMgr.initSlaves(allInfoCallback,true)
	end,Consts.ALL_BOARD_CHECKC_INTERVAL)
	LogUtil.d(TAG,"start startAllBoardCheck")

end

function startTwinkleTask( )
	if twinkleTimerId and sys.timerIsActive(twinkleTimerId) then
		LogUtil.d(TAG,"twinkle started")
		return
	end


	-- 启动一个定时器，负责闪灯，当出货时停止闪灯
	twinkleTimerId = sys.timerLoopStart(function()
			--TODO 后台是否开启了闪灯开关
			if TWINKLE_TYPE_STILL==twinkleOption then 
				return
			end

			--出货中，不集体闪灯
			if Deliver.isDelivering() or Lightup.isLightuping() then
				LogUtil.d(TAG,TAG.." Deliver.isDelivering or Lightup.isLightuping")
				return
			end

			addrs = UARTAllInfoRep.getAllBoardIds(true)

			if not addrs or 0 == #addrs then
				-- LogUtil.d(TAG,TAG.." no slaves found,ignore twinkle")
				return
			end

			-- LogUtil.d(TAG,TAG.." twinkle pos = "..nextTwinklePos)

            twinkle( addrs,nextTwinklePos,Consts.TWINKLE_TIME )

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

function watchdog()
	sys.timerLoopStart(function()
         LogUtil.d(TAG,"feeddog started")
         mywd.feed()--断网了，别忘了喂狗，否则会重启
    end,Consts.FEEDDOG_PERIOD)
end

function run()
	rtos.make_dir(Consts.USER_DIR)--make sure directory exist
	startTimedTask()
	watchdog()

	-- 启动一个延时定时器, 获取板子id
	LogUtil.d(TAG,"run.....111")
	timerId = sys.timerStart(function()
		LogUtil.d(TAG,"start to retrieve slaves")
		if timerId and sys.timerIsActive(timerId) then
			sys.timerStop(timerId)
			timerId = nil
		end

		sys.taskInit(function()
			--首先初始化本地环境，然后成功后，启动mqtt
			UartMgr.init(Consts.UART_ID,Consts.baudRate)

			--获取所有板子id
			UartMgr.initSlaves(allInfoCallback,true)    
			startAllBoardCheck()--增加一个定时获取的，防止出现一次失败的情况
		end)

	end,60*1000)
		
	
	-- 延时启动mqtt服务
	candidateRunTimerId=sys.timerStart(function()
		LogUtil.d(TAG,"start after timeout in retrieving slaves")

		if candidateRunTimerId and sys.timerIsActive(candidateRunTimerId) then
			sys.timerStop(candidateRunTimerId)
			candidateRunTimerId = nil
		end

		-- if  boardIdentified < RETRY_BOARD_COUNT then 
		-- 	retryIdentify()
		-- end

		if not MQTTManager.mqttStarted() then
			sys.taskInit(MQTTManager.startmqtt)
		end

		LogUtil.d(TAG,"start twinkle task")
		startTwinkleTask()
		
	end,60*1000)  

	sys.timerStart(function()
		LogUtil.d(TAG,"start to keep uart alive")

		sys.taskInit(function()
			UartMgr.startKeepUartAlive()  
		end)

	end,100*1000)--初始化uart后90秒
end


sys.taskInit(run)




           
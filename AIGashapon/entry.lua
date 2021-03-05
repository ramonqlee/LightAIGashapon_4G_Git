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
	--压测
	if Consts.DEVICE_TEST_MODE then
		loopTest()
	end

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

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local ORDER_EXPIRED_IN_SEC = 30--订单超时的时间

-- 上传销售日志的的位置
local UPLOAD_POSITION="uploadPos"
local UPLOAD_NORMAL = "normal"--正常出货
local UPLOAD_TIMEOUT_ARRIVAL = "timeoutArrival"--到达即超时
local UPLOAD_BUSY_ARRIVAL = "busyArrival"--到达时有订单在处理
local UPLOAD_ARRIVAL_TRIGGER_TIMEOUT = "arrivalTriggerTimeout"--到达时，有订单超时了
local UPLOAD_TIMER_TIMEOUT= "TimerTimeout"--定时器检测到超时
local UPLOAD_DELIVER_AFTER_TIMEOUT= "DeliverAfterTimeout"--超时后出货
local UPLOAD_LOCK_TIMEOUT= "LockTimeout"--锁超时
local UPLOAD_INVALID_ARRIVAL= "invalidOrder"

--发送指令的时间
local LOCK_OPEN_TIME="openTime"

--发送出货指令后，锁的状态
local LOCK_OPEN_STATE="s1state"
local LOCK_STATE_OPEN = "1"
local LOCK_STATE_CLOSED = "0"
local lastDeliverTime = 0

local timeOutOrderFound=false--是否有用户未扭订单，如果出现了，则在上报后，没有订单的空隙，重启机器

local parallelCount = 1--并发数量
local baseOrderId = 0	
local addrArray = {}
local location = 1

-- 压测策略
--根据扭蛋机数量，然后按照并发数逐级测试
--1. 先1个扭蛋机开锁，开锁扭蛋机出货成功后，进入下一个扭蛋机开锁
--2. 每次增加1个扭蛋机，按照1中的逻辑，开锁，然后全部出货成功后，进入下一轮弹仓
--3. 如果中间开锁后，超过30秒没有收到出货成功，则认为本轮测试失败，停止测试
function loopTest()
	sys.timerLoopStart(TimerFunc,5*1000)

	--TODO 改成随机获取的方式？
	-- 最大弹仓数如何达到
	sys.timerLoopStart(testLockFunc,60*1000)

end

function testLockFunc(id)
    local orderCount = MyUtils.getTableLen(Consts.gBusyMap)
	if orderCount > 0 then
		LogUtil.d(TAG,TAG.."testLockFunc:wait for deliver, busy order count="..orderCount)
		return
	end

    UARTStatRep.setCallback(openLockCallbackInEntry)--设置开锁的回调函数

	addrs = UARTAllInfoRep.getAllBoardIds(true)
    local addrCount = MyUtils.getTableLen(addrs)

	if 0 == addrCount then
		LogUtil.d(TAG,TAG.." testLockFunc:no slaves found,ignore loopTest")
		return
	end

	LogUtil.d(TAG,TAG.." testLockFunc:loopTest count="..addrCount)

	--是否已经超过了，否则的话，从头再来
	if parallelCount > addrCount then
		parallelCount=1
        -- 切换弹仓
        
        location = (location==2 and 1 or 2);
        LogUtil.d(TAG,TAG.." testLockFunc: switch cabinet")
	end

    local pos = 1
	for _,device_seq in pairs(addrs) do
		if timeOutOrderFound then
			LogUtil.d(TAG,TAG.." testLockFunc:loopTest stopped")
			return
		end

        LogUtil.d(TAG,TAG.." testLockFunc:add pos = "..pos.." parallelCount = "..parallelCount)
        if pos == parallelCount then
            local addr = nil
            if "string" == type(device_seq) then
                addr = string.fromHex(device_seq)--pack.pack("b3",0x00,0x00,0x06)  
            elseif "number"==type(device_seq) then
                addr = string.format("%2X",device_seq)
            end

            addrArray[#addrArray+1]=addr

            --批量开锁
            baseOrderId = baseOrderId + loopUnlock(addrArray,baseOrderId)
            addrArray = {}--clear
            parallelCount = parallelCount + 1
            return
        end

        pos = pos + 1
	end

end

function loopUnlock( addrArray ,baseOrderId)
	LogUtil.d(TAG,TAG.." loopUnlock:loopUnlock count="..MyUtils.getTableLen(addrArray))

	local orderCount=0
	for _,addr in pairs(addrArray) do
		-- for pos=1,2 do--两层弹仓
			-- 开锁
			if timeOutOrderFound then
				LogUtil.d(TAG,TAG.." loopUnlock:loopUnlock stopped")
				return
			end

			local saleLogMap = {}
			orderCount = orderCount+1
		    saleLogMap[CloudConsts.ONLINE_ORDER_ID]=string.format("%d",(baseOrderId+orderCount))--当前测试的序号，作为orderID
		    saleLogMap[LOCK_OPEN_TIME]=os.time()
		    saleLogMap[CloudConsts.DEVICE_SEQ]=string.toHex(addr)
            saleLogMap[CloudConsts.VM_ORDER_ID]=saleLogMap[CloudConsts.ONLINE_ORDER_ID]

		    saleLogMap[Deliver.ORDER_TIMEOUT_TIME_IN_SEC]= os.time()+ORDER_EXPIRED_IN_SEC
		    
		    saleLogMap[CloudConsts.LOCATION]=location

		    local r = UARTControlInd.encode(addr,location,ORDER_EXPIRED_IN_SEC)
		    UartMgr.publishMessage(r)
		    LogUtil.d(TAG,TAG.." loopUnlock:loopTest openLock,addr = "..string.toHex(addr).." location="..location)
		    local key = addr.."_"..location
		    Consts.gBusyMap[key]=saleLogMap
		-- end
	end
	return orderCount
end

-- 开锁的回调
-- flagTable:二维数组
function  openLockCallbackInEntry(addr,flagsTable)
    -- 订单开锁，并且出货成功了，直接删除，否则还需要等待如下条件
    -- 如下条件，在定时中实现
    -- 1. 订单过期了，现在是30分钟
    -- 2. 同一location，产生了新的订单

    -- 从订单中查找，如果有的话，则上传相应的销售日志
    if not addr or not flagsTable then
        return
    end

    local orderCount = MyUtils.getTableLen(Consts.gBusyMap)
    LogUtil.d(TAG,TAG.." in openLockCallbackInEntry gBusyMap len="..orderCount.." callback addr="..addr)
    if 0 == orderCount then
        return
    end

    local toRemove = {}
    for key,saleTable in pairs(Consts.gBusyMap) do
        if saleTable then
            seq = saleTable[CloudConsts.DEVICE_SEQ]
            loc = saleTable[CloudConsts.LOCATION]
            orderId = saleTable[CloudConsts.VM_ORDER_ID]

            LogUtil.d(TAG,TAG.." try to handle orderId ="..orderId.." seq = "..seq.." loc = "..loc)

            if loc and seq and seq == addr  then

                --  确认订单状态
                -- 旋扭锁控制状态(S1):
                --     指示当前的旋钮锁，是处于打开还是关闭状态:0 = 关闭;1=打开 
                -- 出货状态(S2):
                --      0为初始化状态  1为出货成功   2为出货超时（在协议设定的时间内用户未操作，锁已恢复锁止状态）
                
                loc = tonumber(loc)
                ok = UARTStatRep.isDeliverOK(loc)

                -- 锁曾经开过，则将其增加到订单状态中，下次不再更新
                lockOpen = UARTStatRep.isLockOpen(loc)
                if lockOpen then
                    saleTable[LOCK_OPEN_STATE] = LOCK_STATE_OPEN
                end

                -- 锁曾经开过，现在关上了，但是没出货
                if LOCK_STATE_OPEN==saleTable[LOCK_OPEN_STATE] and not lockOpen and not ok then
                        -- 上报超时日志
                        LogUtil.d(TAG,TAG.." openLockCallbackInEntry delivered timeout")

                        saleTable[CloudConsts.CTS]=os.time()
                        saleTable[UPLOAD_POSITION]=UPLOAD_LOCK_TIMEOUT
                        -- local saleLogHandler = UploadSaleLog:new()
                        -- saleLogHandler:setMap(saleTable)
                        
                        -- saleLogHandler:send(CRBase.NOT_ROTATE)

                        -- 添加到待删除列表中
                        toRemove[key] = 1
                        LogUtil.d(TAG,TAG.." add to to-remove tab,key = "..key)
                end

                -- 出货成功了
                if ok then
                    LogUtil.d(TAG,TAG.." openLockCallbackInEntry delivered OK")

                    -- 上报出货检测
                    local detectTable = {}
                    detectTable[CloudConsts.AMOUNT]=1
                    detectTable[CloudConsts.SN]=saleTable[CloudConsts.SN]
                    detectTable[CloudConsts.ONLINE_ORDER_ID]=saleTable[CloudConsts.ONLINE_ORDER_ID]

                    -- detectionHandler = UploadDetect:new()
                    -- detectionHandler:setMap(detectTable)
                    -- detectionHandler:send()

                    -- 上报出货日志(如果已经上报过超时，就不再上报了)
                    if not saleTable[UPLOAD_POSITION] then
                        saleTable[CloudConsts.CTS]=os.time()
                        saleTable[UPLOAD_POSITION]=UPLOAD_NORMAL
                        local saleLogHandler = UploadSaleLog:new()
                        saleLogHandler:setMap(saleTable)

                        s = CRBase.SUCCESS
                        if os.time() > saleTable[Deliver.ORDER_TIMEOUT_TIME_IN_SEC] then
                            s = CRBase.DELIVER_AFTER_TIMEOUT--超时出货
                            saleTable[UPLOAD_POSITION]=UPLOAD_DELIVER_AFTER_TIMEOUT
                        end
                        -- saleLogHandler:send(s)
                    end

                    -- 添加到待删除列表中
                    toRemove[key] = 1
                    LogUtil.d(TAG,TAG.." add to to-remove tab,key = "..key)
                else
                    lockstate="close"
                    if lockOpen then
                        lockstate = "open"
                    end
                    LogUtil.d(TAG,TAG.." openLockCallbackInEntry deliver lockstate = "..lockstate)
                end
            end
        end
    end

    --删除已经出货的订单,需要从最大到最小删除，
    if MyUtils.getTableLen(toRemove)>0 then
        lastDeliverTime = os.time()
        LogUtil.d(TAG,TAG.." to remove gBusyMap len="..MyUtils.getTableLen(Consts.gBusyMap))
        for key,_ in pairs(toRemove) do
            Consts.gBusyMap[key]=nil
            LogUtil.d(TAG,TAG.." remove order with key = "..key)
        end
        LogUtil.d(TAG,TAG.." after remove gBusyMap len="..MyUtils.getTableLen(Consts.gBusyMap))
    end
end

function TimerFunc(id)
    local systemTime = os.time()

    if 0 == MyUtils.getTableLen(Consts.gBusyMap) then
        LogUtil.d(TAG,TAG.." in TimerFunc empty gBusyMap")
        return
    end

    if timeOutOrderFound then
    	return
    end
-- 接上条件，在定时中实现（所有如下都基于一个前提，location对应的订单，出货失败时，会自动上报超时，然后触发超时操作）
    -- 1. 订单对应的出货，超过了超时时间；
    --修改为下次同一弹仓出货时，移除这次的或者等待底层硬件上报出货成功后，移除
    local toRemove = {} 

    for key,saleTable in pairs(Consts.gBusyMap) do
        lastDeliverTime = systemTime

        if saleTable then
           -- 是否超时了
           orderTimeoutTime=saleTable[Deliver.ORDER_TIMEOUT_TIME_IN_SEC]
           if orderTimeoutTime then
               orderId = saleTable[CloudConsts.ONLINE_ORDER_ID]
               seq = saleTable[CloudConsts.DEVICE_SEQ]
               loc = saleTable[CloudConsts.LOCATION]

               if systemTime > orderTimeoutTime then
                LogUtil.d(TAG,"TimeoutTable orderId = "..orderId.." seq = "..seq.." loc="..loc.." timeout at "..orderTimeoutTime.." nowTime = "..systemTime)
                
                timeOutOrderFound = true
                --上传超时，如果已经上传过，则不再上传
                if not saleTable[UPLOAD_POSITION] then
                    saleTable[UPLOAD_POSITION]=UPLOAD_TIMER_TIMEOUT
                    saleTable[CloudConsts.CTS]=systemTime

                    local saleLogHandler = UploadSaleLog:new()
                    saleLogHandler:setMap(saleTable)
                    -- saleLogHandler:send(CRBase.NOT_ROTATE)

                    -- toRemove[key] = 1
                end
                end
            end
        end
    end

    --删除已经出货的订单,需要从最大到最小删除，
    if MyUtils.getTableLen(toRemove)>0 then
        lastDeliverTime = os.time()
        LogUtil.d(TAG,TAG.." in TimerFunc to remove gBusyMap len="..MyUtils.getTableLen(Consts.gBusyMap))
        for key,_ in pairs(toRemove) do
            gBusyMap[key]=nil
            LogUtil.d(TAG,TAG.." in TimerFunc  remove order with key = "..key)
        end
        LogUtil.d(TAG,TAG.." in TimerFunc after remove gBusyMap len="..MyUtils.getTableLen(Consts.gBusyMap))
    end

    -- 有用户未扭，并且没有订单了，尝试重启板子，恢复下
    -- if timeOutOrderFound and 0 == getTableLen(gBusyMap) then
    --     MQTTManager.rebootWhenIdle()
    --     LogUtil.d(TAG,"......timeout order found ,it will poweron when device is idle")
    -- end

end  


-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------



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
		if boardIdentified >0 or Consts.BOARD_CHECK_COUNT >= Consts.MAX_BOARD_CHECK_COUNT then
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




           
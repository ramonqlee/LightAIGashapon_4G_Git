-- @module MQTTManager
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.21
module(...,package.seeall)

require "misc"
require "sys"
require "mqtt"
require "link"
require "http"
require "net"
require "Consts"
require "CloudConsts"
require "msgcache"
require "Config"
require "LogUtil"
require "UartMgr"
require "Lightup"
require "GetMachVars"
require "ScanQrCode"
require "Deliver"
require "GetTime"
require "RepTime"
require "SetConfig"
require "MyUtils"
require "ConstsPrivate"

local jsonex = require "jsonex"

-- 断网重连的策略
-- 1.先尝试切换到飞行模式，然后切换回正常模式，此过程耗时3秒
-- 2.等待联网成功，此过程预计耗时9秒
-- 3.以上过过程重复2次，无法联网，改为重启板子恢复联网

local MAX_FLY_MODE_RETRY_COUNT = 2--为了测试方便，设定了10次，实际设定为2次
local MAX_FLY_MODE_WAIT_TIME = 3*Consts.ONE_SEC_IN_MS--实际1秒
local MAX_IP_READY_WAIT_TIME = 9*Consts.ONE_SEC_IN_MS--实际7秒既可以
local HTTP_WAIT_TIME=5*Consts.ONE_SEC_IN_MS

local KEEPALIVE,CLEANSESSION=60,0
local CLEANSESSION_TRUE=1
local MAX_RETRY_SESSION_COUNT=2--重试n次后，如果还事变，则清理服务端的消息
local PROT,ADDR,PORT =ConstsPrivate.MQTT_PROTOCOL,ConstsPrivate.MQTT_ADDR,ConstsPrivate.MQTT_PORT
local QOS,RETAIN=2,1
local CLIENT_COMMAND_TIMEOUT = 5*Consts.ONE_SEC_IN_MS
local CLIENT_COMMAND_SHORT_TIMEOUT = 1*Consts.ONE_SEC_IN_MS
local MAX_MSG_CNT_PER_REQ = 1--每次最多发送的消息数
local mqttc = nil
local toPublishMessages={}

local TAG = "MQTTManager"
local reconnectCount = 0

-- MQTT request
local MQTT_DISCONNECT_REQUEST ="disconnect"
local MAX_MQTT_RECEIVE_COUNT = 2

local toHandleRequests={}
local startmqtted = false
local unsubscribe = false
local lastSystemTime--上次的系统时间

function emptyExtraRequest()
    toHandleRequests={}
    LogUtil.d(TAG," emptyExtraRequest")
end 

function emptyMessageQueue()
      toPublishMessages={}
end

--系统ntp开机后，只同步一次；后续都是在此基础上，通过自有服务器校对时间
--定时校对时间，以内ntp可能出问题，一旦mqtt连接，用自有的时间进行校正
function selfTimeSync()
    if Consts.gTimerId and sys.timerIsActive(Consts.gTimerId) then
        return
    end

    lastSystemTime = os.time()

    --每隔10秒定时查看下当前时间，如果系统时间发生了2倍的时间波动，则用自有时间服务进行校正
    Consts.gTimerId=sys.timerLoopStart(function()
            local timeDiff = lastSystemTime-os.time()
            lastSystemTime = os.time()

            --时间是否同步:时间同步后，设定重启时间
            if Consts.LAST_REBOOT then
                -- 时间走偏了，重新校正
                if timeDiff < 0 then
                    timeDiff = -timeDiff
                end
                --时间是否发生了波动
                if timeDiff < 2*Consts.TIME_SYNC_INTERVAL_MS then
                    return
                end
            end

            --mqtt连接时，用自有时间进行校正
            if not mqttc or not mqttc.connected then
                return
            end

            local handle = GetTime:new()
            handle:sendGetTime(os.time())

            LogUtil.d(TAG,"selfTimeSync now")

        end,Consts.TIME_SYNC_INTERVAL_MS)
end

function getNodeIdAndPasswordFromServer()
    nodeId,password="",""
    -- TODO 
    imei = misc.getImei()
    sn = crypto.md5(imei,#imei)

    url = string.format(ConstsPrivate.MQTT_CONFIG_NODEID_URL_FORMATTER,imei,sn)
    LogUtil.d(TAG,"url = "..url)
    http.request("GET",url,nil,nil,nil,nil,function(result,prompt,head,body )
        if result and body then
            LogUtil.d(TAG,"http config body="..body)
            bodyJson = jsonex.decode(body)

            if bodyJson then
                nodeId = bodyJson['node_id']
                password = bodyJson['password']
            end

            if nodeId and password then
                LogUtil.d(TAG,"http config nodeId="..nodeId)
                MyUtils.saveUserName(nodeId)
                MyUtils.savePassword(password)
            end
        end
        
    end)
end

function checkMQTTUser()
    LogUtil.d(TAG,".............................checkMQTTUser ver=".._G.VERSION)
    username = MyUtils.getUserName(false)
    password = MyUtils.getPassword(false)
    while not username or 0==#username or not password or 0==#password do
         -- mywd.feed()--获取配置中，别忘了喂狗，否则会重启
        getNodeIdAndPasswordFromServer()
        
        sys.wait(HTTP_WAIT_TIME)
        username = MyUtils.getUserName(false)
        password = MyUtils.getPassword(false)

         -- mywd.feed()--获取配置中，别忘了喂狗，否则会重启
        if username and password and #username>0 and #password>0 then
            return username,password
        end
    end
    return username,password
end

function checkNetwork()
    if socket.isReady() then
        LogUtil.d(TAG,".............................checkNetwork socket.isReady,return.............................")
        return
    end

    local netFailCount = 0
    while true do
        --尝试离线模式，实在不行重启板子
        --进入飞行模式，20秒之后，退出飞行模式
        LogUtil.d(TAG,".............................switchFly true.............................")
        net.switchFly(true)
        sys.wait(MAX_FLY_MODE_WAIT_TIME)
        LogUtil.d(TAG,".............................switchFly false.............................")
        net.switchFly(false)

        if not socket.isReady() then
            LogUtil.d(TAG,".............................socket not ready,wait "..MAX_IP_READY_WAIT_TIME)
            --等待网络环境准备就绪，超时时间是40秒
            sys.waitUntil("IP_READY_IND",MAX_IP_READY_WAIT_TIME)
        end

        if socket.isReady() then
            LogUtil.d(TAG,".............................socket ready after retry.............................")
            return
        end

        netFailCount = netFailCount+1
        if netFailCount>=MAX_FLY_MODE_RETRY_COUNT then
            sys.restart("netFailTooLong")--重启更新包生效
        end
    end
end

function connectMQTT()
    local mqttFailCount = 0
    while not mqttc:connect(ADDR,PORT) do
        -- mywd.feed()--获取配置中，别忘了喂狗，否则会重启
        LogUtil.d(TAG,"fail to connect mqtt,mqttc:disconnect,try after 10s")
        mqttc:disconnect()
        
        checkNetwork()
    end
end

function hasMessage()
    return toPublishMessages and  0~= MyUtils.getTableLen(toPublishMessages)
end

--控制每次调用，发送的消息数，防止发送消息，影响了收取消息
function publishMessageQueue(maxMsgPerRequest)
    -- 在此发送消息,避免在不同coroutine中发送的bug
    if not toPublishMessages or 0 == MyUtils.getTableLen(toPublishMessages) then
        LogUtil.d(TAG,"publish message queue is empty")
        return
    end

    if not Consts.DEVICE_ENV then
        --LogUtil.d(TAG,"not device,publish and return")
        return
    end

    if not mqttc then
        --LogUtil.d(TAG,"mqtt empty,ignore this publish")
        return
    end

    if not mqttc.connected then
        --LogUtil.d(TAG,"mqtt not connected,ignore this publish")
        return
    end

    if maxMsgPerRequest <= 0 then
        maxMsgPerRequest = 0
    end

    local toRemove={}
    local count=0
    for key,msg in pairs(toPublishMessages) do
        topic = msg.topic
        payload = msg.payload

        if topic and payload and #topic>0 and #payload>0 then
            LogUtil.d(TAG,"publish topic="..topic.." queue size = "..MyUtils.getTableLen(toPublishMessages))
            local r = mqttc:publish(topic,payload,QOS,RETAIN)
            
            -- 添加到待删除队列
            if r then
                toRemove[key]=1

                LogUtil.d(TAG,"publish payload= "..payload)
                payload = jsonex.decode(payload)
                local content = payload[CloudConsts.CONTENT]
                if content or "table" == type(content) then
                    local sn = content[CloudConsts.SN]
                    msgcache.remove(sn)
                end
            end

            count = count+1
            if maxMsgPerRequest>0 and count>=maxMsgPerRequest then
                -- LogUtil.d(TAG,"publish count set to = "..maxMsgPerRequest)
                break
            end
        else
            toRemove[key]=1--invalid msg
            LogUtil.d(TAG,"invalid message to be removed")
        end 
    end

    -- 清除已经成功的消息
    for key,_ in pairs(toRemove) do
        if key then
            toPublishMessages[key]=nil
        end
    end

end


function handleRequst()

    if not toHandleRequests or 0 == MyUtils.getTableLen(toHandleRequests) then
        LogUtil.d(TAG,"empty handleRequst")
        return
    end

    local toRemove={}
    LogUtil.d(TAG,"mqtt handleRequst")
    for key,req in pairs(toHandleRequests) do

        -- 对于断开mqtt的请求，需要先清空消息队列
        if MQTT_DISCONNECT_REQUEST == req and not MQTTManager.hasMessage() then
            LogUtil.d(TAG,"mqtt MQTT_DISCONNECT_REQUEST")
            if mqttc and mqttc.connected then
                mqttc:disconnect()
            end

            toRemove[key]=1
        end

    end

    -- 清除已经成功的消息
    for key,_ in pairs(toRemove) do
        if key then
            toHandleRequests[key]=nil
        end
    end

end


function publish(topic, payload)
     -- 如果已经不存在绑定关系了，就不要发送该消息了
    local nodeId = MyUtils.getUserName(false)
    if not nodeId or 0 == #nodeId then
        LogUtil.d(TAG,"MQTTManager.publish return for unbound node")
        return
    end 

    toPublishMessages=toPublishMessages or{}
    
    if topic and  payload and #topic>0 and #payload>0 then 
        msg={}
        msg.topic=topic
        msg.payload=payload
        toPublishMessages[crypto.md5(payload,#payload)]=msg
        
        -- TODO 修改为持久化方式，发送消息

        LogUtil.d(TAG,"add to publish queue,topic="..topic.." toPublishMessages len="..MyUtils.getTableLen(toPublishMessages))
    end
end



function loopPreviousMessage( mqttProtocolHandlerPool )
    log.info(TAG, "loopPreviousMessage now")

    while true do
        if not mqttc.connected then
            break
        end

        local r, data = mqttc:receive(CLIENT_COMMAND_TIMEOUT)

        if not data then
            break
        end

        if r and data then
            -- 去除重复的sn消息
            if msgcache.addMsg2Cache(data) then
                for k,v in pairs(mqttProtocolHandlerPool) do
                    if v:handle(data) then
                        log.info(TAG, "loopPreviousMessage reconnectCount="..reconnectCount.." ver=".._G.VERSION.." ostime="..os.time())
                        break
                    end
                end
            else
                log.info(TAG, "loopPreviousMessage dup msg")
            end
        else
            log.info(TAG, "loopPreviousMessage no more msg")
            break
        end
    end

    log.info(TAG, "loopPreviousMessage done")
end


function loopMessage(mqttProtocolHandlerPool)
    while true do
        if not mqttc.connected then
            mqttc:disconnect()
            LogUtil.d(TAG," mqttc.disconnected and no message,mqttc:disconnect() and break") 
            break
        end
        selfTimeSync()--启动时间同步
        
        local timeout = CLIENT_COMMAND_TIMEOUT
        if hasMessage() then
            timeout = CLIENT_COMMAND_SHORT_TIMEOUT
        end

        log.info(TAG, "loopMessage mqttc to receive ostime="..os.time())
        
        local r, data = mqttc:receive(timeout)

        log.info(TAG, "loopMessage mqttc after receive ostime="..os.time())

        if not data then
            mqttc:disconnect()
            LogUtil.d(TAG," mqttc.receive error,mqttc:disconnect() and break") 
            break
        end

        log.info(TAG, "process data reconnectCount="..reconnectCount.." ver=".._G.VERSION.." ostime="..os.time())

        if r and data then--成功收到消息了
            -- 去除重复的sn消息
            if msgcache.addMsg2Cache(data) then
                for k,v in pairs(mqttProtocolHandlerPool) do
                    if v:handle(data) then
                        break
                    end
                end
            end
        else
            if data then--超时了
                log.info(TAG, "msg = "..data.." ostime="..os.time())

                -- 发送待发送的消息，设定条数，防止出现多条带发送时，出现消息堆积
                publishMessageQueue(MAX_MSG_CNT_PER_REQ)
                handleRequst() 
            else--出错了
                LogUtil.d(TAG," mqttc receive false and no message,mqttc:disconnect() and break")

                mqttc:disconnect()
                break
            end
        end

        --oopse disconnect
        if not mqttc.connected then
            mqttc:disconnect()
            LogUtil.d(TAG," mqttc.disconnected and no message,mqttc:disconnect() and break")
            break
        end
    end
end

function disconnect()
    if not mqttc then
        return
    end

    if not toHandleRequests then
        toHandleRequests = {}
    end

    toHandleRequests[#toHandleRequests+1] = MQTT_DISCONNECT_REQUEST
    LogUtil.d(TAG,"add to request queur,request="..MQTT_DISCONNECT_REQUEST.." #toHandleRequests="..#toHandleRequests)
end  


function startmqtt()
    if startmqtted then
        LogUtil.d(TAG,"startmqtted already ver=".._G.VERSION)
        return
    end

    startmqtted = true

    LogUtil.d(TAG,"startmqtt ver=".._G.VERSION.." reconnectCount = "..reconnectCount)
    if not Consts.DEVICE_ENV then
        return
    end

    msgcache.clear()--清理缓存的消息数据

    local cleanSession = CLEANSESSION_TRUE--初始状态，清理session
    while true do
        --检查网络，网络不可用时，会重启机器
        checkNetwork()   

        local USERNAME,PASSWORD = checkMQTTUser()
        while not USERNAME or not PASSWORD or #USERNAME==0 or #PASSWORD==0 do 
            USERNAME,PASSWORD = checkMQTTUser()
        end
        
        local mMqttProtocolHandlerPool={}
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=RepTime:new(nil)
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=SetConfig:new(nil)
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=GetMachVars:new(nil)
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=Deliver:new(nil)
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=Lightup:new(nil)
        mMqttProtocolHandlerPool[#mMqttProtocolHandlerPool+1]=ScanQrCode:new(nil)

        local topics = {}
        for _,v in pairs(mMqttProtocolHandlerPool) do
            topics[string.format("%s/%s", USERNAME,v:name())]=QOS
        end

        LogUtil.d(TAG,".............................startmqtt username="..USERNAME.." ver=".._G.VERSION.." reconnectCount = "..reconnectCount)
        if mqttc then
            mqttc:disconnect()
        end

         --清理服务端的消息
        if reconnectCount>=MAX_RETRY_SESSION_COUNT then
            mqttc = mqtt.client(USERNAME,KEEPALIVE,USERNAME,PASSWORD,cleanSession)
            connectMQTT()
            mqttc:disconnect()

            msgcache.clear()
            -- emptyMessageQueue()
            -- emptyExtraRequest()
            reconnectCount = 0
            LogUtil.d(TAG,".............................startmqtt CLEANSESSION all ".." reconnectCount = "..reconnectCount)
        end

        mqttc = mqtt.client(USERNAME,KEEPALIVE,USERNAME,PASSWORD,cleanSession)

        connectMQTT()
        
        loopPreviousMessage(mMqttProtocolHandlerPool)
        
        --先取消之前的订阅
        if mqttc.connected and not unsubscribe then
            local unsubscribeTopic = string.format("%s/#",USERNAME)
            local r = mqttc:unsubscribe(unsubscribeTopic)
            if r then
                unsubscribe = true
            end
            local result = r and "true" or "false"
            LogUtil.d(TAG,".............................unsubscribe topic = "..unsubscribeTopic.." result = "..result)
        end
        
        if mqttc.connected and mqttc:subscribe(topics) then
            cleanSession = CLEANSESSION--一旦连接成功，保持session
            unsubscribe = false
            LogUtil.d(TAG,".............................subscribe topic ="..jsonex.encode(topics))

            loopMessage(mMqttProtocolHandlerPool)
        end
        reconnectCount = reconnectCount + 1
    end
end


          
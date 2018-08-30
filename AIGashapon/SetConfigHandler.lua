
-- @module SetConfigHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "CloudConsts"
require "CloudBaseHandler"
require "Config"
require "LogUtil"
require "MqttReplyHandlerMgr"
require "ReplyConfigHandler"

local TAG = "SetConfigHandler"

local STATE_INIT = "INIT"

SetConfigHandler = CloudBaseHandler:new{
    MY_TOPIC = "set_config",
}

function SetConfigHandler:new (o)
    o = o or CloudBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function SetConfigHandler:name()
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
function SetConfigHandler:handleContent( content )
	local r = false
 	if (not content) then
 		return
 	end

 	local state = content[CloudConsts.STATE]
 	local sn = content[CloudConsts.SN]
 	if(not state or not sn) then
 		return r
 	end

 	Config.saveValue(CloudConsts.VM_SATE,state)
 	Config.saveValue(CloudConsts.NODE_NAME,content[CloudConsts.NODE_NAME])
 	Config.saveValue(CloudConsts.NODE_PRICE,content[CloudConsts.NODE_PRICE])
 	Config.saveValue(CloudConsts.REBOOT_SCHEDULE,content[CloudConsts.REBOOT_SCHEDULE])

 	nodeName = Config.getValue(CloudConsts.NODE_NAME)
 	if nodeName then
 		LogUtil.d(TAG,"state ="..state.." node_name="..nodeName)
 	else
 		LogUtil.d(TAG,"nodeName is empty")
 	end

 	local map={}
 	map[CloudConsts.SN]=sn
 	map[CloudConsts.STATE]=state
 	map[CloudConsts.NODE_NAME]=content[CloudConsts.NODE_NAME]
 	map[CloudConsts.NODE_PRICE]=content[CloudConsts.NODE_PRICE]
 	map[CloudConsts.REBOOT_SCHEDULE]=content[CloudConsts.REBOOT_SCHEDULE]
    local arriveTime = content[CloudConsts.ARRIVE_TIME]
    if arriveTime then
        map[CloudConsts.ARRIVE_TIME]= arriveTime    
    end

 	-- print(ReplyConfigHandler.MY_TOPIC)
 	MqttReplyHandlerMgr.replyWith(ReplyConfigHandler.MY_TOPIC,map)

 	-- 恢复初始状态
 	if STATE_INIT==state then
    	LogUtil.d(TAG,"state ="..state.." clear nodeId and password")
        Consts.clearUserName()
        Consts.clearPassword()
        
    	MQTTManager.disconnect()
    	return
    end
end   


-- @module GetMachineVars
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2018.8.30

require "CloudConsts"
require "CloudBaseHandler"
require "MqttReplyHandlerMgr"
require "LogUtil"
local jsonex = require "jsonex"

local TAG = "GetMachineVars"

GetMachineVars = CloudBaseHandler:new{
    MY_TOPIC = "get_machine_variables",
}

function GetMachineVars:new (o)
    o = o or CloudBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function GetMachineVars:name()
    return self.MY_TOPIC
end

-- testPushStr = [[
-- {
--     "topic": "1000001/get_machine_variables",
--     "payload": {
--         "timestamp": "1400000000",
--         "content": {
--             "sn": "19291322"
--         }
--     }
-- }
-- ]]

function GetMachineVars:handleContent( content )
 	if not content then
 		return false
 	end


 	local map = {}
 	map[CloudConsts.SN]=content[CloudConsts.SN]
	local arriveTime = content[CloudConsts.ARRIVE_TIME]
    if arriveTime then
        map[CloudConsts.ARRIVE_TIME]= arriveTime    
    end
    
 	-- --LogUtil.d(TAG,TAG.." handleContent ="..jsonex.encode(map))
 	MqttReplyHandlerMgr.replyWith(ReplyMachineVars.MY_TOPIC,map)
 	
 	return true
end       

-- @module MqttReplyHandlerMgr
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "Consts"
require "LogUtil"
require "CloudConsts"
require "ReplyMachineVars"
require "ReplyConfigHandler"
require "ReplyDeliverHandler"

local jsonex = require "jsonex"

local TAG = "MqttReplyHandlerMgr"
local handlerTable={}
MqttReplyHandlerMgr ={
}

local function getTableLen( tab )
    local count = 0  

    if "table"~=type(tab) then
        return count
    end

    for k,_ in pairs(tab) do  
        count = count + 1  
    end 

    return count
end

--注册处理器，如果已经注册过，直接覆盖
function MqttReplyHandlerMgr.registerHandler( handler )
	if not handler then
		return
	end

	if (not handler:name()) then
		return
	end

	handlerTable[handler:name()]=handler
end

function MqttReplyHandlerMgr.makesureInit()
	if getTableLen(handlerTable)>0 then
		return
	end

	MqttReplyHandlerMgr.registerHandler(ReplyMachineVars:new(nil))
	MqttReplyHandlerMgr.registerHandler(ReplyConfigHandler:new(nil))
	MqttReplyHandlerMgr.registerHandler(ReplyDeliverHandler:new(nil))
end

function MqttReplyHandlerMgr.replyWith(topic,payload)
	MqttReplyHandlerMgr.makesureInit()
	if nil == handlerTable then
		return
	end

	local object = handlerTable[topic]
	if not object then
		return
	end

	-- if Consts.LOG_ENABLED then
	LogUtil.d(TAG,"MqttReplyHandlerMgr payload "..jsonex.encode(payload))
	-- end

	local inObject={}
	inObject[CloudConsts.TOPIC] = topic
	--增加payload
	inObject[CloudConsts.PAYLOAD]=payload
	
	-- if Consts.LOG_ENABLED then
	-- 	LogUtil.d(TAG,TAG.." replyWith object = "..jsonex.encode( inObject))
	-- end
	
	return object:handle(inObject)
end     
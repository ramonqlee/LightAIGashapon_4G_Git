
-- @module MQTTReplyMgr
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27
module(...,package.seeall)

require "Consts"
require "LogUtil"
require "CloudConsts"
require "RepMachVars"
require "RepConfig"
require "RepDeliver"

local jsonex = require "jsonex"

local TAG = "MQTTReplyMgr"
local handlerTable={}


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
function registerHandler( handler )
	if not handler then
		return
	end

	if (not handler:name()) then
		return
	end

	handlerTable[handler:name()]=handler
end

function makesureInit()
	if getTableLen(handlerTable)>0 then
		return
	end

	registerHandler(RepMachVars:new(nil))
	registerHandler(RepConfig:new(nil))
	registerHandler(RepDeliver:new(nil))
end

function replyWith(topic,payload)
	makesureInit()
	if nil == handlerTable then
		return
	end

	local object = handlerTable[topic]
	if not object then
		return
	end

	-- if Consts.LOG_ENABLED then
	LogUtil.d(TAG,"MQTTReplyMgr payload "..jsonex.encode(payload))
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


   
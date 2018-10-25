-- @module CRBase
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.21
-- tested 2017.12.27

require "LogUtil"
require "CloudConsts"
-- require "MQTTManager"
require "Consts"
local jsonex = require "jsonex"

CRBase = {
    --状态定义:“state”: 1, //1成功，2收到并处理指令时已超时，3硬件出货失败，4硬件繁忙，5币量不足，6币售空，13未旋转,99状态未知
    SUCCESS = 1,
    TIMEOUT_WHEN_ARRIVE=2,
    FAIL = 3,
    BUSY = 4,
    INSUFFICIENT = 5,
    EMPTY = 6,
    NOT_ROTATE = 13,--未旋转
    DELIVER_AFTER_TIMEOUT=14,--超时出货
    UNKNOWN = 99,
}

local TAG = "CRBase"
-- Derived class method new
function CRBase:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CRBase:getTopic(  )
	local nodeId = MyUtils.getUserName()
	if not nodeId or  0 == #nodeId then
		return ""
	end

	return string.format("%s/%s", nodeId, self:name())
end

function CRBase:handle( object )

	-- --LogUtil.d(TAG,TAG.." handle now")

	local r = false
	if not object then
		return r
	end

	if Consts.LOG_ENABLED then
		-- --LogUtil.d(TAG,TAG.." handle object="..jsonex.encode( object))
	end

	local myTopic = object[CloudConsts.TOPIC]
	if (not myTopic)then 
		return r
	end

	-- --LogUtil.d(TAG,"myTopic = "..myTopic.." name="..self:name())

	if string.upper(myTopic) ~= string.upper(self:name()) then
		return r
	end

	return self:handleContent(object[CloudConsts.PAYLOAD])
end

function CRBase:handleContent( payloadJsons )
	-- --LogUtil.d(TAG,TAG.." CRBase:handleContent now")

	local myPayload = {}
	local myContent = payloadJsons or {}

	myPayload[CloudConsts.TIMESTAMP]=os.time()
	self:addExtraPayloadContent(myContent)
	myPayload[CloudConsts.CONTENT]=myContent
	
	local myTopic = self:getTopic()
	local tmp = jsonex.encode(myPayload)
	if Consts.LOG_ENABLED then
	-- 	--LogUtil.d(TAG,TAG.." handleContent topic ="..myTopic)
		--LogUtil.d(TAG,TAG.." payload = "..tmp)
	end

	MQTTManager.publish(myTopic,tmp)
	return true
end

    

-- @module UploadDetection
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- @test 2018.1.7

require "CloudConsts"
require "CloudReplyBaseHandler"
jsonex = require "jsonex"

local TAG = "UploadDetection"
UploadDetection = CloudReplyBaseHandler:new{
    MY_TOPIC = "upload_deliver_detection",
    mPayload ={}
}

function UploadDetection:new (o)
    o = o or CloudReplyBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function UploadDetection:name()
    return self.MY_TOPIC
end

function UploadDetection:setMap( payload )
	self.mPayload = payload
end

function UploadDetection:addExtraPayloadContent( content )
end

function UploadDetection:send()
	local myContent = {}
 	for k,v in pairs(self.mPayload) do
 		myContent[k]=v
 	end

 	local myPayload = {}
 	myPayload[CloudConsts.TIMESTAMP]=os.time()
 	myPayload[CloudConsts.CONTENT]=myContent
 	MQTTManager.publish(self:getTopic(),jsonex.encode(myPayload))
end         
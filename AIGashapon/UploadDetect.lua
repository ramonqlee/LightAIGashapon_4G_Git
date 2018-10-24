
-- @module UploadDetect
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- @test 2018.1.7

require "CloudConsts"
require "CRBase"
jsonex = require "jsonex"

local TAG = "UploadDetect"
UploadDetect = CRBase:new{
    MY_TOPIC = "upload_deliver_detection",
    mPayload ={}
}

function UploadDetect:new (o)
    o = o or CRBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function UploadDetect:name()
    return self.MY_TOPIC
end

function UploadDetect:setMap( payload )
	self.mPayload = payload
end

function UploadDetect:addExtraPayloadContent( content )
end

function UploadDetect:send()
	local myContent = {}
 	for k,v in pairs(self.mPayload) do
 		myContent[k]=v
 	end

 	local myPayload = {}
 	myPayload[CloudConsts.TIMESTAMP]=os.time()
 	myPayload[CloudConsts.CONTENT]=myContent
 	MQTTManager.publish(self:getTopic(),jsonex.encode(myPayload))
end

         
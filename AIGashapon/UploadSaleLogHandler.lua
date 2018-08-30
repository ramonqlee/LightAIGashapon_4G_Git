
-- @module UploadSaleLogHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- @test 2018.1.7

require "CloudConsts"
require "CloudReplyBaseHandler"
jsonex = require "jsonex"

local TAG = "UploadSaleLogHandler"
UploadSaleLogHandler = CloudReplyBaseHandler:new{
    MY_TOPIC = "upload_sale_log",
    mPayload ={}
}

function UploadSaleLogHandler:new (o)
    o = o or CloudReplyBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function UploadSaleLogHandler:name()
    return self.MY_TOPIC
end

function UploadSaleLogHandler:setMap( payload )
	self.mPayload = payload
end

function UploadSaleLogHandler:addExtraPayloadContent( content )
end

function UploadSaleLogHandler:send( state )
	local myContent = {}
 	for k,v in pairs(self.mPayload) do
 		myContent[k]=v
 	end
 	myContent[CloudConsts.STATE]=state
 	local myPayload = {}
 	myPayload[CloudConsts.TIMESTAMP]=os.time()
 	myPayload[CloudConsts.CONTENT]=myContent
 	MQTTManager.publish(self:getTopic(),jsonex.encode(myPayload))
end         
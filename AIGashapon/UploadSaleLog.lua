
-- @module UploadSaleLog
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- @test 2018.1.7

require "CloudConsts"
require "CRBase"
jsonex = require "jsonex"

local TAG = "UploadSaleLog"
UploadSaleLog = CRBase:new{
    MY_TOPIC = "upload_sale_log",
    mPayload ={}
}

function UploadSaleLog:new(o)
    o = o or CRBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function UploadSaleLog:name()
    return self.MY_TOPIC
end

function UploadSaleLog:setMap( payload )
	self.mPayload = payload
end

function UploadSaleLog:addExtraPayloadContent( content )
end

function UploadSaleLog:send( state )
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


        
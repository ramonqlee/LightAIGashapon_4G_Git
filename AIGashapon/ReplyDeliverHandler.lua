
-- @module ReplyDeliverHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23

require "CloudReplyBaseHandler"

local TAG = "ReplyDeliverHandler"

ReplyDeliverHandler = CloudReplyBaseHandler:new{
    MY_TOPIC = "reply_deliver"
}

function ReplyDeliverHandler:new (o)
    o = o or CloudReplyBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end


function ReplyDeliverHandler:name()
    return self.MY_TOPIC
end

function ReplyDeliverHandler:addExtraPayloadContent( content )
 	
end                 
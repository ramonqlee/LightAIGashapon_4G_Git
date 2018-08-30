
-- @module ReplyConfigHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "CloudConsts"
require "CloudReplyBaseHandler"

local TAG = "ReplyConfigHandler"

ReplyConfigHandler = CloudReplyBaseHandler:new{
    MY_TOPIC = "reply_config"
}

function ReplyConfigHandler:new (o)
    o = o or CloudReplyBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReplyConfigHandler:name()
    return self.MY_TOPIC
end

function ReplyConfigHandler:addExtraPayloadContent( content )
 	
end     
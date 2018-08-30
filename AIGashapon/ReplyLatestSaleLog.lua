
-- @module ReplyLatestSaleLog
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "CloudConsts"
require "CloudReplyBaseHandler"

local TAG = "ReplyLatestSaleLog"
ReplyLatestSaleLog = CloudReplyBaseHandler:new{
    MY_TOPIC = "reply_last_sale_log_id",
}

function ReplyLatestSaleLog:new (o)
    o = o or CloudReplyBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReplyLatestSaleLog:name()
    return self.MY_TOPIC
end

function ReplyLatestSaleLog:addExtraPayloadContent( content )
 	
end   
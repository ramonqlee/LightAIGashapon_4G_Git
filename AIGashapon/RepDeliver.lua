
-- @module RepDeliver
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23

require "CRBase"

local TAG = "RepDeliver"

RepDeliver = CRBase:new{
    MY_TOPIC = "reply_deliver"
}

function RepDeliver:new (o)
    o = o or CRBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end


function RepDeliver:name()
    return self.MY_TOPIC
end

function RepDeliver:addExtraPayloadContent( content )
 	
end     

            
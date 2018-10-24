
-- @module RepConfig
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2018.8.30

require "CloudConsts"
require "CRBase"

local TAG = "RepConfig"

RepConfig = CRBase:new{
    MY_TOPIC = "reply_config"
}

function RepConfig:new (o)
    o = o or CRBase:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function RepConfig:name()
    return self.MY_TOPIC
end

function RepConfig:addExtraPayloadContent( content )
 	
end    


 
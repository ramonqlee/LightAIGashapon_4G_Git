
-- @module GetLogHandler
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23

require "CloudConsts"

local TAG = "GetLogHandler"
GetLogHandler = {
    MY_TOPIC = "get_log",
}

function GetLogHandler:name()
    return self.MY_TOPIC
end

function GetLogHandler:handleContent( content )
 	-- TODO to be coded
end
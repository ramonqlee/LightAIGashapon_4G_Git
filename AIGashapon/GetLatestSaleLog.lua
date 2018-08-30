
-- @module GetLatestSaleLog
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "Config"
require "CloudConsts"
require "CloudBaseHandler"
require "MqttReplyHandlerMgr"
require "ReplyLatestSaleLog"

local TAG = "GetLatestSaleLog"
GetLatestSaleLog = CloudBaseHandler:new{
    MY_TOPIC = "get_last_sale_log_id",
}

function GetLatestSaleLog:new (o)
    o = o or CloudBaseHandler:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function GetLatestSaleLog:name()
    return self.MY_TOPIC
end

-- testPushStr = [[
-- {
--     "topic": "1000001/get_last_sale_log_id",
--     "payload": {
--         "timestamp": "1400000000",
--         "content": {
--             "sn": "19291322"
--         }
--     }
-- }
-- ]]

function GetLatestSaleLog:handleContent( content )
 	if(not content) then
 		return false
 	end

 	local map ={}
 	map[CloudConsts.SN]=content[CloudConsts.SN]
 	local lastId = Config.getValue(CloudConsts.LAST_ID)

 	--oops,no last sale
 	if not lastId then
 		return
 	end

 	map[CloudConsts.LAST_ID] = lastId
 	MqttReplyHandlerMgr.replyWith(ReplyLatestSaleLog.MY_TOPIC, map)
end

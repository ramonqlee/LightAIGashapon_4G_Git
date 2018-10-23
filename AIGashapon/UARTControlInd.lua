
-- @module UARTControlInd
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29
module(...,package.seeall)

require "UARTUtils"


local MT = 0x12

function encode( addr,loc,timeoutInSec )
	-- TODO待根据格式组装报文
 	data = pack.pack("b2",0,loc)
 	data = data..pack.pack(">h",timeoutInSec)
 	
 	sf = pack.pack("b",UARTUtils.SEND)
 	mt = pack.pack("b",MT)
 	return UARTUtils.encode(sf,addr,mt,data)
end       



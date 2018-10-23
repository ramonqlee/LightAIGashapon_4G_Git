
-- @module UARTGetAllInfo
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29
module(...,package.seeall)

require "UARTUtils"

local MT=0x13


function encode()
-- TODO待根据格式组装报文
 	data = pack.pack("b",0)--type=0

 	-- --LogUtil.d(TAG,"UARTGetAllInfo pack data = "..string.toHex(data))
 	
 	-- function  UARTUtils.encode( sf,addr,mt,data )
 	sf = pack.pack("b",UARTUtils.SEND)
 	addr = pack.pack("b3",0x0,0x0,0x0)
 	mt = pack.pack("b",MT)
 	return UARTUtils.encode(sf,addr,mt,data)
end 



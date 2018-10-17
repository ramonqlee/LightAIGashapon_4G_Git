
-- @module UARTLockClose
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29

require "UARTUtils"

UARTLockClose={
	MT = 0x12
}

function UARTLockClose.encode( addr,loc )
	-- TODO待根据格式组装报文
 	data = pack.pack("b2",1,loc)
 	
 	sf = pack.pack("b",UARTUtils.SEND)
 	mt = pack.pack("b",UARTControlInd.MT)
 	return UARTUtils.encode(sf,addr,mt,data)
end       



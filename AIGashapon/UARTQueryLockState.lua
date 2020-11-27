
-- @module UARTQueryLockState
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2020.04.12

require "UARTUtils"

UARTQueryLockState={
	MT = 0x11
}

function UARTQueryLockState.encode()
 	data = pack.pack("b",0)--type=0

 	sf = pack.pack("b",UARTUtils.SEND)
 	addr = pack.pack("b3",0x0,0x0,0x0)
 	mt = pack.pack("b",UARTQueryLockState.MT)
 	return UARTUtils.encode(sf,addr,mt,data)
end







-- @module UARTControlInd
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2018.10.19

require "UARTUtils"

UARTPlayAudio={
	MT = 0x15,
	OPENLOCK_AUDIO = 0x1,--购买成功后
	SCAN_AUDIO = 0x2-- 扫码声音；
}

function UARTPlayAudio.encode( audioIndex)
	-- TODO待根据格式组装报文
 	data = pack.pack("b",audioIndex)
 	
 	sf = pack.pack("b",UARTUtils.SEND)
 	mt = pack.pack("b",UARTPlayAudio.MT)
 	addr = pack.pack("b3",0x0,0x0,0x0)
 	return UARTUtils.encode(sf,addr,mt,data)
end       



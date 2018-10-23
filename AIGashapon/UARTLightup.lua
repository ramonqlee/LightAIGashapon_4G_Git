
-- @module UARTLightup
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29
module(...,package.seeall)

require "UARTUtils"
require "LogUtil"

local MT = 0xFF

-- boardId = v["id"]--3 bytes
-- group = v["group"]--1byte
-- color = v["color"]--1bye
-- time = v["time"]--2byte
function encode( msgArray )
	-- TODO待根据格式组装报文
 	data = pack.pack("b",1)--msgType=1
 	data = data..pack.pack("b",#msgArray)--Length

 	for i,v in pairs(msgArray) do
 		boardId = v["id"]--3 bytes
 		group = v["group"]--1byte
 		color = v["color"]--1bye
 		time = v["time"]--2byte

 		temp = boardId..group..color..time
		-- LogUtil.d(TAG,"UARTLightup pack temp = "..UARTUtils.binstohexs(temp))
 		data = data..temp
 	end

 	--LogUtil.d(TAG,"UARTLightup pack data = "..UARTUtils.binstohexs(data))
 	sf = pack.pack("b",UARTUtils.SEND)
 	addr = pack.pack("b3",0x0,0x0,0x0)
 	mt = pack.pack("b",MT)
 	return UARTUtils.encode(sf,addr,mt,data)
end        



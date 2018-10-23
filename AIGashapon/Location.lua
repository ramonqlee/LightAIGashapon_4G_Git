
-- @module Location
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
module(...,package.seeall)


BUS_ADDRESS_OFFSET = 1
MIN_BUS_ADDRESS = 0
MAX_BUS_ADDRESS = 31
ALL_BUS_ADDRESS = 0xff

local mBusAddress = 0--总线地址

function setBusAddress( address )
	mBusAddress=address
end

function getBusAddress() 
	return mBusAddress
end      



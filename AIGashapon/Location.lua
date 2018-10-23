
-- @module Location
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23

Location = {
BUS_ADDRESS_OFFSET = 1,
MIN_BUS_ADDRESS = 0,
MAX_BUS_ADDRESS = 31,
ALL_BUS_ADDRESS = 0xff,

mBusAddress = 0--总线地址
}

function Location.setBusAddress( address )
	Location.mBusAddress=address
end

function Location.getBusAddress() 
	return Location.mBusAddress
end      



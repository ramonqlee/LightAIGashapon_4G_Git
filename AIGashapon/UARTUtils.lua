
-- @module UARTUtils
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- @tested 2018.01.28
module(...,package.seeall)

require "LogUtil"

local TAG = "UARTUtils"

SEND = 0xC7
RCV = 0xC8


function chk( msg )
	-- unsigned short i, j; unsigned short crc = 0; unsigned short current;
	-- for (i = 0; i < len; i++)
	-- {
	-- current = msg[i] << 8;
	-- for (j = 0; j < 8; j++)
	-- {
	-- 	if ((short)(crc ^ current) < 0)
	-- 		crc = (crc << 1) ^ 0x1221;
	-- 	else
	-- 		crc <<= 1;
	-- current <<= 1;
	-- } 
	-- }
	-- return crc;

	local crc = 0
	if msg == nil or type(msg) ~= "string" then 
		return bit.band(crc,0xffff)--确保是short类型的数据
	end

	-- --LogUtil.d(TAG,"checking= "..string.toHex(msg))
	for i=1,string.len(msg) do
		v = string.byte(msg,i)
		-- --LogUtil.d(TAG,"chk v= "..v.." for i = "..i)

		current = bit.lshift(v,8)
		-- --LogUtil.d(TAG,"chk current= "..current)

		for j=0,7 do
			current = bit.band(current,0xffff)--确保是short类型的数据
			crc = bit.band(crc,0xffff)--确保是short类型的数据

			t=bit.bxor(crc,current)
			if(bit.isset(t,15)) then
				crc=bit.bxor(bit.lshift(crc,1),0x1221)
			else
				crc=bit.lshift(crc,1)
			end

			-- --LogUtil.d(TAG,"chk crc= "..crc.." for j = "..j)
			current=bit.lshift(current,1)
			-- --LogUtil.d(TAG,"chk current= "..current)
		end
	end
	return bit.band(crc,0xffff)--确保是short类型的数据
end  

function  encode( sf,addr,mt,data )
	if not sf or not addr or not mt then
		return
	end

	-- TODO 待组装发送的数据
	len = #data+6
	len = pack.pack("b",len)

	-- 如果address不足3位，则补充0
	if #addr < 3 then
		len = 3-#addr
		for i=1,len do
			addr = pack.pack("b",0x0)..addr
		end
	end
	
	r = sf..len..addr..mt..data
	-- --LogUtil.d(TAG,"encode to chk = "..string.toHex(r))

	chk = chk(r)

	-- --LogUtil.d(TAG,"encode chk = "..chk)

	chk = pack.pack(">h",chk)
	r = r..chk

	-- --LogUtil.d(TAG,"encode = "..string.toHex(r))
	return r
end            

--[[
函数名：binstohexs
功能  ：二进制数据 转化为 16进制字符串格式，例如91688121364265f7 （表示第1个字节是0x91，第2个字节为0x68，......） -> "91688121364265f7"
参数  ：
		bins：二进制数据
		s：转换后，每两个字节之间的分隔符，默认没有分隔符
返回值：转换后的字符串
]]
function binstohexs(bins,s)
	local hexs = "" 

	if bins == nil or type(bins) ~= "string" then return nil,"nil input string" end

	for i=1,string.len(bins) do
		hexs = hexs .. string.format("%02X",string.byte(bins,i)) ..(s==nil and "" or s)
	end
	hexs = string.upper(hexs)
	return hexs
end
 


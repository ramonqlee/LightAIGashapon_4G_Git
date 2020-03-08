-- @module UARTBoardInfo
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29
-- @tested 2018.2.3

require "LogUtil"

local TAG = "UARTBoardInfo"

UARTBoardInfo = {
	MT = 0x90
}

local masterBoardId="UNDEF"
local myCallback = nil

function  UARTBoardInfo.setCallback( callback )
	myCallback = callback
end

--返回最后匹配的一个字节位置
function UARTBoardInfo.handle(bins)
	local noMatch=-1
	-- 回调
	-- 返回协议数据，上报机器状态用
	-- 首先校验合法性
	-- 开始数据，数据长度，地址，类型，校验和

	if bins == nil or type(bins) ~= "string" then return noMatch,noMatch end

		--找到开始的数据
		local ignoreHeaderLen = 2
		local startPos = -1
		for i=1,#bins do
			if UARTUtils.RCV == string.byte(bins,i) then
				startPos=i
				-- --LogUtil.d(TAG,"find startPos = "..startPos)
				break
			end
		end

		if startPos < 0 then
			return noMatch,startPos
		end

		local lenPos=startPos+1
		local boardIdAddressPos = lenPos+1
		local messageTypePos = boardIdAddressPos+3
		local dataPos = messageTypePos+1
		tmp = string.byte(bins,lenPos)

		if messageTypePos > #bins then
			return noMatch,startPos
		end

		mt = string.byte(bins,messageTypePos)
		if mt ~= UARTBoardInfo.MT then
			-- --LogUtil.d(TAG,"illegal MT,mt = "..mt.." my MT = "..UARTBoardInfo.MT)
			return noMatch,startPos
		end


		local chkPos = lenPos+tmp-1

	-- 长度是否合法
	if #bins < boardIdAddressPos then
		-- --LogUtil.d(TAG,"illegal boardIdAddressPos")
		return noMatch,startPos
	end

	len = string.byte(bins,lenPos)
	if #bins<len+ignoreHeaderLen then
		-- --LogUtil.d(TAG,"illegal length")
		return noMatch,startPos
	end

	-- 校验和是否合法
	chkInBin = string.sub(bins,chkPos,chkPos+1)
	temp = string.sub(bins,startPos+2,chkPos-1)

	chk = UARTUtils.chk(temp)
	chkInHex = string.format("%04X",chk)
	-- --LogUtil.d(TAG,"to chk ="..string.toHex(temp) .." chkPos ="..chkPos.." chk="..chkInHex)

	if chkInHex ~= string.toHex(chkInBin) then
		-- --LogUtil.d(TAG,"illegal chk,calculate chkInHex ="..chkInHex.." chkInBin="..string.toHex(chkInBin))
		return noMatch,startPos
	end



	idLen = string.byte(bins,dataPos+1)
	idPos = dataPos+2

	if 0 == idLen then
		-- --LogUtil.d(TAG,"no id returned")
		return chkPos+1,startPos
	end

	local boardIdTemp = string.sub(bins,idPos,idPos+idLen-1)
	if boardIdTemp and type(boardIdTemp)=="string" and #boardIdTemp>0 then
		masterBoardId = string.toHex(boardIdTemp)
	end
	-- softi d ignore
	if myCallback then
		myCallback(masterBoardId)
	end

	return chkPos+1,startPos
end

function UARTAllInfoRep.getMasterBoardId()
	return masterBoardId
end


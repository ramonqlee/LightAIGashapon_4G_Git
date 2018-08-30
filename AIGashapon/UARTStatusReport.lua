-- @module UARTStatusReport
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.29
-- @tested 2018.2.3

require "LogUtil"
UARTStatusReport = {
MT=0x91
}

local mCallback = nil
local status=""
local address=""
local TAG = "UARTStatusReport"

-- 旋扭锁控制状态(S1):
--     指示当前的旋钮锁，是处于打开还是关闭状态:0 = 关闭;1=打开 
local LOCK_STATE_OPEN = 1
local LOCK_STATE_CLOSE = 0

-- 出货状态(S2):
-- 0为初始化状态  1为出货成功   2为出货超时（在协议设定的时间内用户未操作，锁已恢复锁止状态）
local DELIVER_STATE_INIT = 0
local DELIVER_STATE_OK = 1
local DELIVER_STATE_TIMEOUT = 2

function  UARTStatusReport.setCallback( callback )
	mCallback = callback	
end

function UARTStatusReport.getMyAddress( )
	return address
end 

function UARTStatusReport.isLockOpen( group )
	s1,_=UARTStatusReport.getStates(group)
	return LOCK_STATE_OPEN==s1
end

function UARTStatusReport.isLockClose( group )
	s1,_=UARTStatusReport.getStates(group)
	return LOCK_STATE_CLOSE==s1
end

function UARTStatusReport.isDeliverOK( group )
	_,s2=UARTStatusReport.getStates(group)
	return DELIVER_STATE_OK==s2
end

function UARTStatusReport.isDeliverTimeout( group )
	_,s2=UARTStatusReport.getStates(group)
	return DELIVER_STATE_TIMEOUT==s2
end


--返回第几组,group start from 1
-- 形如：01 02 00 00 00 00 
function UARTStatusReport.getStates(group)
	s1,s2=-1,-1
	if not group or not status or #status<6 then
		LogUtil.d(TAG,"illegal status")
		return s1,s2
	end
	
	-- return status
	if (group==1) then
		 s1 = string.byte(status,1)
		 s2 = string.byte(status,2)
	end

	if (group==2) then
	 	s1 = string.byte(status,3)
	 	s2 = string.byte(status,4)
	end

	if (group==3) then
	 	s1 = string.byte(status,5)
	 	s2 = string.byte(status,6)
	end

	-- LogUtil.d(TAG,"UARTStatusReport.getStates group ="..group.." s1 = "..s1.." s2 = "..s2)
	return s1,s2
end

function UARTStatusReport.handle(bins)
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
				-- LogUtil.d(TAG,"find startPos = "..startPos)
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
		if mt ~= UARTStatusReport.MT then
			-- LogUtil.d(TAG,"illegal MT,mt = "..mt.." my MT = "..UARTStatusReport.MT)
			return noMatch,startPos
		end

		local chkPos = lenPos+tmp-1

	-- 长度是否合法
	if #bins < boardIdAddressPos then
		-- LogUtil.d(TAG,"illegal boardIdAddressPos")
		return noMatch,startPos
	end

	len = string.byte(bins,lenPos)
	if #bins<len+ignoreHeaderLen then
		-- LogUtil.d(TAG,"illegal length")
		return noMatch,startPos
	end

	-- 校验和是否合法
	chkInBin = string.sub(bins,chkPos,chkPos+1)
	temp = string.sub(bins,startPos+2,chkPos-1)

	-- LogUtil.d(TAG,"to chk ="..string.tohex(temp) .." chkPos ="..chkPos)

	chk = UARTUtils.chk(temp)
	chkInHex = string.format("%04X",chk)

	if chkInHex ~= string.tohex(chkInBin) then
		-- LogUtil.d(TAG,"illegal chk,calculate chkInHex ="..chkInHex.." chkInBin="..string.tohex(chkInBin))
		return noMatch,startPos
	end

	status = string.sub(bins,dataPos+4)--直接读取状态，跳过运行时间

	address = string.sub(bins,boardIdAddressPos,boardIdAddressPos+2)
	LogUtil.d(TAG,"address = "..string.tohex(address).." status = "..string.tohex(status))
	
	if mCallback then
		mCallback(string.tohex(address),status)
	end

	return chkPos+1,startPos
end    


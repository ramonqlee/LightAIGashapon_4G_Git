
-- @module RepMachVars
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2018.8.30

require "CloudConsts"
require "CRBase"
require "sim"
require "UARTAllInfoRep"

local TAG = "RepMachVars"
local DEFAULT_JS_VERSION = "1"

RepMachVars = CRBase:new{
	MY_TOPIC = "reply_machine_variables"
}

function RepMachVars:new(o)
	o = o or CRBase:new(o)
	setmetatable(o, self)
	self.__index = self
	return o
end

function RepMachVars:name()
	return self.MY_TOPIC
end

function RepMachVars:addExtraPayloadContent( content )
	if not content then 
		return
	end

	-- FIXME 待赋值
	content["mac"]= misc.getImei()
	content["imei"]=misc.getImei()
	content["iccid"]=sim.getIccid()--sim卡卡号

	local t = Consts.LAST_REBOOT
	if not t then
		t = os.time()
	end

	if Consts.masterBoardId then
		content["masterBoardId"]=Consts.masterBoardId
	end
	
	content["all_board_count"]=Consts.ALL_BOARD_COUNT
	content["board_check_count"]=Consts.BOARD_CHECK_COUNT

	content["uart_broke_time"]=Consts.UART_BROKE_COUNT--uart 断开的次数
	content["uart_keep_alive_time"]=Consts.lastKeepAliveTime--最近一次心跳的时间
	Consts.UART_BROKE_COUNT = 0

	content["last_reboot"] =  t --0--用户标识时间未同步
	-- FIXME 待赋值
	content["signal_strength"]=net.getRssi()
	content["app_version"]="NIUQUMCS-4G-".._G.VERSION
	if TEST_SERVER then
		content["app_version"]=content["app_version"].."-Test"
	end
	local devices={}

	local CATEGORY = "sem"
	bds = UARTAllInfoRep.getAllBoardIds(true)
	if bds and #bds >0 then
		for _,v in pairs(bds) do
			local device ={}
			device["category"]=CATEGORY
			device["seq"]=v
			device["from"]=UARTAllInfoRep.boardIdFrom(v)

			arr = {}
			-- var = {}
			-- var["malfunction"]="0"
			-- arr[#arr+1]=var

			device["variables"]=arr

			devices[#devices+1]=device

			--LogUtil.d(TAG,"RepMachVars device = "..v)
		end
	end

	if 0 == #devices then
		local device ={}
		device["category"]=CATEGORY
		device["seq"]=0

		arr = {}
		-- var = {}
		-- var["malfunction"]="0"
		-- arr[#arr+1]=var

		device["variables"]=arr

		devices[#devices+1]=device
	end

	content["devices"]=devices

	--upload iccid by http
	local nodeId = MyUtils.getUserName(false)
    if not nodeId or 0 == #nodeId then
        LogUtil.d(TAG,"return for unbound node")
        return
    end 
	url = string.format(ConstsPrivate.API_UPLOAD_VM_MSG_URL_FORMATTER,nodeId,content["iccid"],content["mac"])
    LogUtil.d(TAG,"upload_vm_msg url = "..url)
    http.request("GET",url,nil,nil,nil,nil,function(result,prompt,head,body )
        if result and body then
            LogUtil.d(TAG,"upload_vm_msg http body="..body)
        end
    end)
end  


      
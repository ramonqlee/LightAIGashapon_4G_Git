
-- @module ReplyMachineVars
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "CloudConsts"
require "CloudReplyBaseHandler"
require "Location"
require "UARTAllInfoReport"

local TAG = "ReplyMachineVars"
local DEFAULT_JS_VERSION = "1"

ReplyMachineVars = CloudReplyBaseHandler:new{
MY_TOPIC = "reply_machine_variables",
-- mState=0
}

function ReplyMachineVars:new (o)
	o = o or CloudReplyBaseHandler:new(o)
	setmetatable(o, self)
	self.__index = self
	return o
end

function ReplyMachineVars:name()
	return self.MY_TOPIC
end

function ReplyMachineVars:setState(state)
	self.mState=state
end

function ReplyMachineVars:addExtraPayloadContent( content )
	if not content then 
		return
	end

	-- FIXME 待赋值
	content["mac"]= misc.getImei()
	content["imei"]=misc.getImei()

	local t = Consts.LAST_REBOOT
	if not t then
		t = os.time()
	end
	
	content["last_reboot"] =  t --0--用户标识时间未同步
	-- FIXME 待赋值
	content["signal_strength"]=net.getRssi()
	content["app_version"]="NIUQUMCS-01-".._G.VERSION
	local devices={}

	local CATEGORY = "sem"
	bds = UARTAllInfoReport.getAllBoardIds(true)
	if bds and #bds >0 then
		for _,v in pairs(bds) do
			local device ={}
			device["category"]=CATEGORY
			device["seq"]=v

			arr = {}
			-- var = {}
			-- var["malfunction"]="0"
			-- arr[#arr+1]=var

			device["variables"]=arr

			devices[#devices+1]=device

			--LogUtil.d(TAG,"ReplyMachineVars device = "..v)
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
end        
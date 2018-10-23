
-- @module Task
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.27
-- @tested 2018.
module(...,package.seeall)

require "Consts"
require "LogUtil"
require "UartMgr"
require "UARTSlave"
require "sys"

local NONE_TASK = "NONE"
local BODY_KEY = "body"
local TASK_KEY = "task"
local TOKEN_KEY = "token"

-- 重启
REBOOT_TYPE = "REBOOT"

local TAG = "Task"
local isRunning = false

function getTask()
	if isRunning then
		return
	end

	sys.taskInit(function()
		-- 去服务器端请求任务
		local nodeId = LogUtil.getUserName(false)
		local password = LogUtil.getPassword(false)
		if not nodeId or 0 == #nodeId or not password or 0 == #password then
			LogUtil.d(TAG,"unregistered node")
			return
		end

		local timeInSec = os.time()
	    local timestamp = ""..timeInSec
		local nonce   = crypto.sha1(timestamp,#timestamp)
		local pwsha1 = crypto.sha1(password,#password)
		nonce = string.lower(nonce)
		pwsha1 = string.lower(pwsha1)

		local tmp = nodeId..pwsha1..nonce..timestamp

		-- LogUtil.d(TAG,"nodeId = "..nodeId.." tmp="..tmp)
	    sign = crypto.sha1(tmp,#tmp)
	    sign = string.lower(sign)

		url = string.format(Consts.MQTT_TASK_URL_FORMATTER,nodeId, nonce, timestamp, sign)
	    LogUtil.d(TAG,"url = "..url)

	    isRunning = true
    	http.request("GET",url,nil,nil,nil,nil,function(result,prompt,head,body )
    		isRunning = false
    		
	        if result and body then
	            LogUtil.d(TAG,"http config body="..body)
			    bodyJson = jsonex.decode(body)

			    if not bodyJson then
			        return
			    end

			    bodyVal = bodyJson[BODY_KEY]
			    if not bodyVal or "table"~=type(bodyVal) then
			    	return
			    end

			    task = bodyVal[TASK_KEY]
			    -- 任务分发(目前仅仅支持重启，后续待完善框架，支持更多任务)
			    -- FIXME 待增加从板子支持
			    if task == REBOOT_TYPE then 
			    	r = UARTSlave.encode()
					UartMgr.publishMessage(r)

					sys.wait(5000)--等待大板子发送消息完毕，目前大板子发送消息的间隔是500ms
			    	LogUtil.d(TAG,"publish cmd = "..Consts.REBOOT_DEVICE_CMD)
			    	sys.publish(Consts.REBOOT_DEVICE_CMD)
			    end
	        end
    	end)

	end)

end
    



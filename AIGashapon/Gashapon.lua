
-- @module Gashapon
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.21

require "Config"

local url ="https://j.azls.mobi/node/register"
local method = "POST"
local timeout = 30
local params = {}
local data = {}
params.imei = "868675022176012"
params.sn = "05M111300760726"


function  httptest(  )
	while not socket.isReady() do 
		print("socket not ready,waiting 10s")
		sys.wait(10000) 
	end

	response_code, response_header, response_body = http.request(method, url, timeout, params, data)
	if 200 == response_code then
		-- print(response_body)
		print("http ok")
	else
		print("response_code = "..response_code)
	end
	print(".........................boot ok.........................")
end

key = "test"
value = Config.getValue(key)
if value then
	print("value = "..value)
end

Config.saveValue(key,"v2")
value = Config.getValue(key)
print("value = "..value)
-- sys.taskInit(httptest)






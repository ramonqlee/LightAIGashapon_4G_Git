-- @module Config
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

require "LogUtil"
require "FileUtil"
require "Consts"

local jsonex=require "jsonex"

local TAG = "Config"
Config = {}

if Consts.DEVICE_ENV then
	Config.CONFIG_FILE = Consts.USER_DIR.."/niuqu_config.dat"
else
	Config.CONFIG_FILE = "niuqu_config.dat"
end

function Config.getValue(key)
	-- --LogUtil.d(TAG,"config file name ="..Config.CONFIG_FILE)
	
	local content = FileUtil.readfile(Config.CONFIG_FILE)

	if content then 
		content= jsonex.decode(content)
	else
		content={}
	end

	if not content then
		return nil
	end

	return content[key]
end


function Config.saveValue(key,value)
	-- --LogUtil.d(TAG,"saveValue key = "..key.." value = "..value)
	if not key then
		return nil
	end

	local content = FileUtil.readfile(Config.CONFIG_FILE)

	if content and #content >0 then
		content = jsonex.decode(content)
	else
		content={}
	end

	if not content then
		content={}
		--LogUtil.d(TAG,"content is set to empty")
	end

	content[key]=value
	content = jsonex.encode(content)

	if not content then
		return
	end

	-- LogUtil.d(TAG,TAG.." config saveValue = "..content)

	FileUtil.writevalw(Config.CONFIG_FILE,content)
end 


  
-- @module NodeIdConfig
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27

local jsonex=require "jsonex"
require "LogUtil"
require "FileUtil"
require "Consts"


local TAG = "NodeIdConfig"
NodeIdConfig = {}

if Consts.DEVICE_ENV then
	NodeIdConfig.CONFIG_FILE = Consts.USER_DIR.."/nodeid_config.dat"
else
	NodeIdConfig.CONFIG_FILE = "nodeid_config.dat"
end

function NodeIdConfig.getValue(key)
	
	local content = FileUtil.readfile(NodeIdConfig.CONFIG_FILE)

	if "string"==type(content) and #content>0 then
		content= jsonex.decode(content)
	else
		content={}
	end

	if not content then
		return nil
	end

	return content[key]
end


function NodeIdConfig.saveValue(key,value)
	if not key then
		return nil
	end

	local content = FileUtil.readfile(NodeIdConfig.CONFIG_FILE)

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

	FileUtil.writevalw(NodeIdConfig.CONFIG_FILE,content)
end  

 
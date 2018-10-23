-- @module NodeIdConfig
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.23
-- tested 2017.12.27
module(...,package.seeall)

local jsonex=require "jsonex"
require "LogUtil"
require "FileUtil"
require "Consts"


local TAG = "NodeIdConfig"
local CONFIG_FILE = Consts.USER_DIR.."/nodeid_config.dat"


function getValue(key)
	
	local content = FileUtil.readfile(CONFIG_FILE)

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


function saveValue(key,value)
	if not key then
		return nil
	end

	local content = FileUtil.readfile(CONFIG_FILE)

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

	FileUtil.writevalw(CONFIG_FILE,content)
end  

 
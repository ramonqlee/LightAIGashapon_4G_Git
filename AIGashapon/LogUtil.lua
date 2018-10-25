-- @module LogUtil
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.24
-- tested 2017.12.27

require "Consts"

LogUtil={}

function LogUtil.d(tag,log) 
	if not Consts.LOG_ENABLED then
		return
	end

	if not tag then
		tag = ""
	end

	if not log then
		log = ""
	end

	print("<"..tag..">\t"..log)
end


       
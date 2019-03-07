-- @module LogUtil
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.24
-- tested 2017.12.27

require "Consts"
require "FileUtil"

LOG_FILE = Consts.USER_DIR.."/niuqu_log.txt"

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

	if Consts.LOG_FILE_ENABLED then
		FileUtil.writevala(LOG_FILE,log)
	end

	if Consts.PRINT_LOG_FILE_ENABLED and Consts.timeSynced then
		--打印文件
		print("..................LOG_FILE NOW..................")
		FileUtil.print(LOG_FILE)
	end

	print("<"..tag..">\t"..log)
end


       
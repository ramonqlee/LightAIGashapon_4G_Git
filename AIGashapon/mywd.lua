-- @module Consts
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.24

--整体逻辑，在调用喂狗时，翻转电平

require "pins"
require "LogUtil"

local wd_val=0--上次喂狗的电平
local wd=nil--喂狗函数
local TAG = "MYWD"
mywd={}

local function init()
	if wd and "function"== type(wd) then
		return
	end

	wd = pins.setup(pio.P0_30,wd_val)
	LogUtil.d(TAG,"feeddog init type(wd) ="..type(wd))
end

function mywd.feed()
	init()
	if not wd or "function"~= type(wd) then
		return
	end

	LogUtil.d(TAG,"feeddog wd_val = "..wd_val)
	wd(wd_val)

	--喂完立即翻转，为下一次做准备
	if 0 == wd_val then 
		wd_val = 1
	else
		wd_val = 0
	end

end



--- 模块功能：TRACE测试模块.
-- @author openLuat
-- @module trace
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27

module(...,package.seeall)

require"rtos"


sys.timerLoopStart(log.info,1000,"trace demo port=",rtos.get_trace_port())


-- @module Consts
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2017.12.24
module(...,package.seeall)

DEVICE_ENV=true -- 是否设备环境
LOG_ENABLED=true --是否关闭日志
TEST_MODE=false--是否启用测试模式，启用代码中的点位id
UART_ID = 2--2123
CONSOLE_UART_ID = 1
baudRate = 115200
WAIT_UART_INTERVAL = 500--等待新数据写入串口的时间间隔
USER_DIR = "/user_dir"--文件存储目录

LAST_REBOOT=nil
TASK_WAIT_IN_MS = 3000--请求网络任务时，强制当前任务延时执行
FEEDDOG_PERIOD = 30*1000--定时喂狗的周期（ms）
MAX_LOOP_INTERVAL = 3*60
MAX_TIME_SYNC_COUNT = 2--时间同步重试次数
TIME_SYNC_INTERVAL_MS = 30*1000--时间同步发起的间隔
-- FIXME TEMP CODE
TIMED_TASK_INTERVAL_MS = 10*60*1000--定时任务检测的时间
MIN_TIME_SYNC_OFFSET = 60--校对时间允许的误差

TWINKLE_TIME_DELAY = 60--距离上次购买多长时间后，再次待机

REBOOT_DEVICE_CMD="REBOOT_DEVICE_CMD"--重启设备命令
LAST_UPDATE_TIME="lastUpdateTime"
LAST_TASK_TIME="lastTaskTime"
UNSUBSCRIBE_KEY ="unsubscribe"
TWINKLE_INTERVAL = 4*1000--切换闪灯的周期:比闪灯时间多2秒
TWINKLE_TIME = 2--待机闪灯的次数(每次闪灯共耗时1s)
-- LOCK_AUDIO = "/ldata/xiaowanzi.mp3"
gTimerId=nil
timeSynced = nil
timeSyncCount=0
RETRY_OPEN_LOCK=false--是否开启重新开锁功能
EANBLE_MERGE_BOARD_ID = false--是否合并所有获得的小板子id
   


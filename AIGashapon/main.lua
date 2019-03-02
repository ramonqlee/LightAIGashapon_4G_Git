--必须在这个位置定义PROJECT和VERSION变量
--PROJECT：ascii string类型，可以随便定义，只要不使用,就行
--VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "AIGashapon"

VERSION = "1.1.195"

--[[
使用Luat物联云平台固件升级的功能，必须按照以下步骤操作：
1、打开Luat物联云平台前端页面：https://iot.openluat.com/
2、如果没有用户名，注册用户
3、注册用户之后，如果没有对应的项目，创建一个新项目
4、进入对应的项目，点击左边的项目信息，右边会出现信息内容，找到ProductKey：把ProductKey的内容，赋值给PRODUCT_KEY变量
]]
PRODUCT_KEY = "WbMTLT8KVFC2VRel181eWa7JOfBAOddk"

-- FIXME 暂时注释掉
-- 日志级别
require "log"
LOG_LEVEL=log.LOGLEVEL_TRACE


require "sys"
require "net"

--每1分钟查询一次GSM信号强度
--每1分钟查询一次基站信息
net.startQueryAll(60000, 60000)

require "entry"

-- 启动系统框架
sys.init(0, 0)
sys.run()




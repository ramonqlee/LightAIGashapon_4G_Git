-- @module msgcache
-- @author ramonqlee
-- @copyright idreems.com
-- @release 2018.2.8
module(...,package.seeall)

require "LogUtil"
require "Config"
require "jsonex"

local MAX_MQTT_CACHE_COUNT = 15--缓存的最大数量
local DECR_MQTT_CACHE_COUNT = 5--超过条数后，每次删除的数量
local SN_SET_PERSISTENCE_KEY="msg_sn_set"

local TAG = "MSGCACHE"

function clear()
    Config.saveValue(SN_SET_PERSISTENCE_KEY,"")
    LogUtil.d(TAG,"clear msgcache")
end


function remove(sn)
    if not sn or "string"~=type(sn) then
        return
    end

    LogUtil.d(TAG,"start to remove msg,sn ="..sn)
    --从文件中提取历史消息，然后进行追加
    local mqttMsgSet = {}
    local allset = Config.getValue(SN_SET_PERSISTENCE_KEY)
    if allset and "string"==type(allset) and #allset>0 then
        mqttMsgSet = jsonex.decode(allset)
    end 

    if not mqttMsgSet then
        return
    end  

    local existed = false
    for i=#mqttMsgSet,1,-1 do
        if mqttMsgSet[i] == sn then
            table.remove(mqttMsgSet, i)
            existed = true
        end
    end
    
    if not existed then
        return
    end

    Config.saveValue(SN_SET_PERSISTENCE_KEY,jsonex.encode(mqttMsgSet))
    LogUtil.d(TAG,sn.."reduce queue's sn = "..sn.." new size="..#mqttMsgSet)
end

--添加到msg缓存,如果不存在，则返回true；如果已经存在，则返回false
function addMsg2Cache(msg)
    local r = false
    --解析msg中的sn
    if not msg then
        return r
    end

    local tableObj = msg
    if "string"==type(tableObj) then
        tableObj = jsonex.decode(msg)
    end

    if not tableObj or "table"~=type(tableObj) then
        return r
    end

    local payload = tableObj[CloudConsts.PAYLOAD]
    if "string"==type(payload) then
      payload = jsonex.decode(payload)
  end

  if not payload or "table" ~= type(payload) then
    return r
  end


    local content = payload[CloudConsts.CONTENT]
    if not content or "table" ~= type(content) then
        LogUtil.d(TAG,"illegal content,return")
        return r
    end

    local sn = content[CloudConsts.SN]
    if not sn or "string"~= type(sn) then
        LogUtil.d(TAG,"no sn,no cache")
        return true--不缓存，直接向下传递
    end

    --从文件中提取历史消息，然后进行追加
    local mqttMsgSet = {}
    local allset = Config.getValue(SN_SET_PERSISTENCE_KEY)
    if allset and "string"==type(allset) and #allset>0 then
        mqttMsgSet = jsonex.decode(allset)
    end 

    if not mqttMsgSet then
        mqttMsgSet = {}
    end  

    local existed = false
    for _,value in pairs(mqttMsgSet) do
        if value == sn then
         LogUtil.d(TAG,sn.." duplicate sn in queue,sn="..sn)
         existed = true
         break
        end
    end
    LogUtil.d(TAG,jsonex.encode(content).."added, queue size = "..#mqttMsgSet)

    local updated = false
    --不存在的话，则记录下
    if not existed then
        mqttMsgSet[#mqttMsgSet+1]=sn
        r = true
        updated = true
    end

    --缓存数量超了，删除最早加入的那些
    if #mqttMsgSet >= MAX_MQTT_CACHE_COUNT then
        --从头部开始删除
        for i=1,DECR_MQTT_CACHE_COUNT do
            if 0 == #mqttMsgSet then
                break
            end
            table.remove(mqttMsgSet,1)
            updated = true
        end    
    end

    --是否需要更新文件
    if updated then
         Config.saveValue(SN_SET_PERSISTENCE_KEY,jsonex.encode(mqttMsgSet))
         LogUtil.d(TAG,sn.." update queue,size="..#mqttMsgSet)
    end

    return r
end     



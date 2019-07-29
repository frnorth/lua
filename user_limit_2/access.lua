local time = ngx.now()

local name_limit_tab = {
                         "namn1", "wangjie";
                         "name2", "superadmin-wj"
                       }
local max_act_per5s = 10

-- connect the redis ==========================================================================================
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000)
local ok, err = red:connect("192.168.1.95", 6380)
if not ok then
    ngx.log(ngx.ERR, "===================== redis redis redis failed to connect redis redis redis ===================: ", err)
    return
end

-- deal the req ==================================================================================================
local h, err = ngx.req.get_headers()
local session = ""
local name = ""
if h ~= nil
then
    local coo = h["cookie"]
    if coo ~= nil
    then
        for k, v in string.gmatch(h["cookie"],"(SESSION)=([^;]+)")
        do
            session = v;
        end
    end
    --local cooo = string.format("%s-ooooo", coo)
    --for k, v in pairs(h)
    --do
    --    red:hset(cooo, k, v)
    --end
end

--ngx.req.read_body()
--local args, err = ngx.req.get_post_args()
--if args ~= nil
--then
--    for key, val in pairs(args) do
--        ngx.log(ngx.ERR, "||||||||||||||||||||| ", key, ": ", val, " cookie: ", session, " ||||||||||||||||||||||||")
--    end
--end

local shared = ngx.shared.shared
if shared ~= nil
then
    local value = shared:get(session)
    --ngx.log(ngx.ERR, "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk , body_num  ((( " , value, " ))) , cookie  ((( ", session, " ))) kkkkkkkkkkkkkkkkkkkkkkkkkkkk")
    shared:delete(session)
    if value ~= nil
    then
        local body = ""
        for i = 0, value
        do
            local session_i = string.format("%s-%d", session, i)
            --red:hset(session, i, tostring(shared:get(session_i)))
            body = body .. tostring(shared:get(session_i))
            shared:delete(session_i)
        end
        for k, v in string.gmatch(body, "\"([%w_%-]*)[\\\"]*:[\\\"]*([%w_%-]*)\"*")
        do
            red:hset(session, k, v)
        end
        --red:hset(session, "data", body)
        red:expire(session, 14400)
    end
end
if session ~= nil
then
    name = red:hget(session, "login_name")
    ngx.log(ngx.ERR, "NNNNNNNNNNNNNNNNNNNNNNNNN user ((( ", name," ))) , uri  ((( " , ngx.var.uri, " ))) , cookie  ((( ", session, " ))) NNNNNNNNNNNNNNNNNNNNNNNNNNNN")
end

-- time count ==================================================================================================
local time_cnt = shared:get_stale("time_cnt")
if time_cnt == nil then
    shared:set("time_cnt", 0)
    time_cnt = 0
end
if time_cnt > 30 then
    shared:flush_all()
    shared:flush_expired()
end
local time_period = ngx.now() - time
shared:replace("time_cnt", time_cnt + time_period)
red:set("time_period", time_period)
red:set("time_cnt", time_cnt)

-- limit the require =============================================================================================
local stats = 0
for k, v in pairs(name_limit_tab)
do
    if name == v
    then
        stats = 1
    end
end

if stats == 1 then

    local name_time_ori = string.format("%s-time-ori", name)
    local name_time_last = string.format("%s-time-last", name)
    local name_act_last = string.format("%s-act-last", name)
    local name_act = string.format("%s-act", name)
    local now = math.floor(ngx.now())

    local ori_time = shared:get(name_time_ori)
    if ori_time == nil then
        shared:set(name_time_ori, now)
        ori_time = now
    else
        ori_time = math.floor(ori_time)
    end

    local last_time = shared:get(name_time_last)
    if last_time == nil then
        shared:set(name_time_last, 0)
        last_time = 0
    end

    local now_time = now - ori_time

    local period = now_time - last_time

    local acts = shared:get(name_act)
    if acts == nil then
        shared:set(name_act, 0)
    else
        acts = acts + 1
        shared:replace(name_act, acts)
    end

    local acts_last = shared:get(name_act_last)
    if acts_last == nil then
        shared:set(name_act_last, 0)
        acts_last = 0
    end

    local sleep_time = 0    
    if acts_last > max_act_per5s then
        sleep_time = (acts_last / max_act_per5s - 1) * 5 / acts_last
    end
    ngx.log(ngx.ERR, " user ((( ", name," ))) , uri  ((( " , ngx.var.uri, " )))  sleep: ((( ", sleep_time, " ))) seconds ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    if sleep_time ~= nil then
        ngx.sleep(sleep_time)
    end
    
 
    if period >= 5 then
        red:hset(name, last_time, acts)
        red:hset(name, "acts_last", acts_last)
        shared:replace(name_act, 0)
        -- 如果不加上 *2, 那么因为延迟的误差, 可能会让每5秒操作数为11 12, 这样还是大于max_act_per5s，于是还是会被替换成acts_last, 所以下次sleep就会按照被替换后的acts_last来计算了  
        if acts > (max_act_per5s * 2) then
            shared:replace(name_act_last, acts)
        end
        shared:replace(name_time_last, now_time)
    end

    if now_time >= 300 then
        shared:replace(name_time_ori, now)
        shared:replace(name_time_last, 0)
        red:del(name)
        shared:replace(name_act_last, 0)
    end
end
-- ////////////////////////////////////////////////////////////////////////////////

local ok, err = red:close()
if not ok then
    ngx.log(ngx.ERR, "===================== redis redis redis failed to close redis redis redis ===================: ", err)
    return
end

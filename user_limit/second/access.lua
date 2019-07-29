local time = ngx.now()

local name_limit = "superadmin-wj"
--local name_limit = "wangjie"
--local uri_limit = "all"
local uri_limit = "ecg"
--local uri_limit = "patient"

local delay_act = 50
local reject_act = 20
local delay_rate = 0.05
local delay_magnify = 10

-- connect the redis ==========================================================================================
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000)
local ok, err = red:connect("192.168.1.95", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
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
end
local shared = ngx.shared.shared
if shared ~= nil
then
    local value = shared:get(session)
    shared:delete(session)
    if value ~= nil
    then
        local body = ""
        for i = 0, value
        do
            local session_i = string.format("%s-%d", session, i)
            body = body .. tostring(shared:get(session_i))
            shared:delete(session_i)
        end
        for k, v in string.gmatch(body, "\"([%w_%-]*)\":\"*([%w_%-]*)\"*")
        do
            red:hset(session, k, v)
        end
        red:expire(session, 14400)
    end
end
if session ~= nil
then
    name = red:hget(session, "login_name")
    --ngx.log(ngx.ERR, "NNNNNNNNNNNNNNNNNNNNNNNNN user ((( ", name," ))) , uri  ((( " , ngx.var.uri, " )))  NNNNNNNNNNNNNNNNNNNNNNNNNNNN")
end

-- limit the require =============================================================================================
local delay = 0
local err = ""
local limit_key = ""
if name == name_limit then
    if string.find(ngx.var.uri, uri_limit) then
        limit_key = uri_limit
    elseif uri_limit == "all" then
        limit_key = name_limit 
    end
end
if limit_key ~= "" then
    local limit_req = require "resty.limit.req"
    local lim, err = limit_req.new("limit_req_store", delay_act, reject_act)
    if not lim then
        ngx.log(ngx.ERR,
                "failed to instantiate a resty.limit.req object: ", err)
        return ngx.exit(500)
    end
    local delay_l, err_l = lim:incoming(limit_key, true)
    if not delay_l then
        if err_l == "rejected" then
            ngx.log(ngx.ERR, " user ((( ", name," ))) , uri  ((( " , ngx.var.uri, " )))  rejected -----------------------------------------------------------------------------------------------------------------------------------")
            return ngx.exit(503)
        end
        ngx.log(ngx.ERR, "failed to limit req: ", err)
        return ngx.exit(500)
    end
    delay = delay_l
    err = err_l
end

local time_cnt = shared:get_stale("time_cnt")
if time_cnt == nil then
    shared:set("time_cnt", 0)
    time_cnt = 0
end
local time_period = ngx.now() - time
shared:replace("time_cnt", time_cnt + time_period)
red:set("time_period", time_period)
red:set("time_cnt", time_cnt)

if delay >= delay_rate then
    local excess = err
    delay = delay * delay_magnify
    ngx.log(ngx.ERR, " user ((( ", name," ))) , uri  ((( " , ngx.var.uri, " )))  delayed by: ((( ", delay, " ))) seconds ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    ngx.sleep(delay)
end

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

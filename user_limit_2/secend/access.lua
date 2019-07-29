local name_limit = "superadmin-wj"
--local name_limit = "wangjie"
--local uri_limit = "all"
local uri_limit = "ecg"
--local uri_limit = "patient"

local delay_act = 20
local reject_act = 10
local delay_rate = 0.01
local delay_magnify = 50

-- connect the redis ==========================================================================================
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000) -- 1 sec
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

-- deal the req ==================================================================================================
local h, err = ngx.req.get_headers()
local session = "" --string.match(h["cookie"]
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
    --for k in shared:get_keys()
    --do
    local value = shared:get(session)
    if value ~= nil
    then
        ngx.log(ngx.ERR, "+++++++++++++++++++++++++++((( shared ", session, ": ", value," )))+++++++++++++++++++++++++++++++++++++")
        for i = 0, value
        do
            local body_idr = string.format("%s-%d", session, i)
            local body = tostring(shared:get(body_idr))
            for k, v in string.gmatch(body, "\"([%w_%-]*)\":\"*([%w_%-]*)\"*")
            do
                red:hset(session, k, v)
            end
            shared:delete(body_idr)
            --red:set(i, body)
        end
    end
end
--shared:flush_all()
--shared:flush_expired()

if session ~= nil
then
    name = red:hget(session, "login_name")
    ngx.log(ngx.ERR, "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN  name: ", name,"  NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN")
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
            ngx.log(ngx.ERR, "JJJJJJJJJJJJJJJJJJJJJJJJJJJ reject JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ")
            return ngx.exit(503)
        end
        ngx.log(ngx.ERR, "failed to limit req: ", err)
        return ngx.exit(500)
    end
    delay = delay_l
    err = err_l
    ngx.log(ngx.ERR, "DDDDDDDDDDDLLLLLLLLLLLLLLL delay_l: ", delay_l," LLLLLLLLLLLLLLLLLDDDDDDDDDDDDDD")
end

-- time keeping  ==============================================================================================
--local time_cnt = count:get_stale("time_cnt")
--if time_cnt == nil then
--    count:set("time_cnt", 0)
--    time_cnt = 0
--end
--local time_period = ngx.now() - time
--count:replace("time_cnt", time_cnt + time_period)
--red:set("time_period", time_period)
--red:set("time_cnt", time_cnt)

--if delay >= 0.001 then
if delay >= delay_rate then
    local excess = err
    delay = delay * delay_magnify
    ngx.log(ngx.ERR, "DDDDDDDDDDDDDDDDDDDDDDDD delay: ", delay, " DDDDDDDDDDDDDDDDDDDDDDDDDD")
    ngx.sleep(delay)
end

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

function fcount(count, c, tab)
    if c == nil then
        count:set(tab, 0)
    else
        count:replace(tab, c + 1)
    end
end

-- connect the redis ==========================================================================================
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000) -- 1 sec
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

-- time keeping  ==============================================================================================
local time = ngx.now()

-- 计数, header.lua body.lua access.lua被调用的次数 ===========================================================
local count, err = ngx.shared.count
local access_cnt = count:get_stale("access_cnt")
local body_cnt = count:get_stale("body_cnt")
local header_cnt = count:get_stale("header_cnt")
local body_cnt_last = count:get_stale("body_cnt_last")
if body_cnt_last == nil then
    count:set("body_cnt_last", 0)
    body_cnt_last = 0
end
fcount(count, access_cnt, "access_cnt")

-- header access start ========================================================================================
-- 因为, 第一次请求时候, ngx.shared.body还是空的, 如果这里不进行判断, 则会直接报错, 貌似, access在body_filter前面  shared, 没有被清空, 所以要想想办法.
local header_shared = ngx.shared.header
local resp_cookie = tostring(header_shared:get_stale("Set_Cookie"))
local session = ""
if resp_cookie ~= nil
then
    for k, v in string.gmatch(resp_cookie,"(SESSION)=([^;]+)")
    do
        session = v;
    end
end

-- body access start ==========================================================================================
local body_shared = ngx.shared.body
local id0 = string.format("body-%d", body_cnt_last)
local i = body_cnt_last
if body_cnt ~= nil
then
    while (i <= body_cnt)
    do
        local id = string.format("body-%d", i)
        local str0 = body_shared:get_stale(id0)
        local str1 = body_shared:get_stale(id)
        body_shared:replace(id0, string.format("%s%s", str0, str1))
        --red:set(id0, body_shared:get_stale(id0))
        i = i + 1
    end
end
if body_cnt ~= nil then count:replace("body_cnt_last", body_cnt + 1) end

-- hset the information of user  ==============================================================================
local str = body_shared:get_stale(id0)
if str ~= nil
then
    if string.find(str, "success")
    then
        for k, v in string.gmatch(str, "\"([%w_%-]*)\":\"*([%w_%-]*)\"*") do
            red:hset(session, k, v)
        end
    end
end
body_shared:flush_all()
body_shared:flush_expired()

-- deal the req ==================================================================================================
local h, err = ngx.req.get_headers()
local req_cookie = "" --string.match(h["cookie"]
local name = ""

if h ~= nil
then
    local coo = h["cookie"]
    if coo ~= nil
    then
        for k, v in string.gmatch(h["cookie"],"(SESSION)=([^;]+)")
        do
            req_cookie = v;
        end
    end
end

if req_cookie ~= nil
then
    name = red:hmget(req_cookie, "login_name")
    ngx.log(ngx.ERR, "NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN  name: ", name[1],"  NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN")
end

-- limit the require =============================================================================================
local name_need_limit = "user1"
local delay = 0
local err = ""
if name[1] == name_need_limit
then
    local limit_req = require "resty.limit.req"
    local lim, err = limit_req.new("limit_req_store", 50, 5)
    if not lim then
        ngx.log(ngx.ERR,
                "failed to instantiate a resty.limit.req object: ", err)
        return ngx.exit(500)
    end
    local delay_l, err_l = lim:incoming(name_need_limit, true)
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
local time_cnt = count:get_stale("time_cnt")
if time_cnt == nil then
    count:set("time_cnt", 0)
    time_cnt = 0
end
local time_period = ngx.now() - time
count:replace("time_cnt", time_cnt + time_period)
red:set("time_period", time_period)
red:set("time_cnt", time_cnt)

--if delay >= 0.001 then
if delay >= 0.05 then
    local excess = err
    delay = delay * 50
    ngx.log(ngx.ERR, "DDDDDDDDDDDDDDDDDDDDDDDD delay: ", delay, " DDDDDDDDDDDDDDDDDDDDDDDDDD")
    ngx.sleep(delay)
end

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

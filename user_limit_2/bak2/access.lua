function fcount(count, c, tab)
    if c == nil then
        count:set(tab, 0)
        ngx.log(ngx.ERR, "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ init ", tab, "{{{SUCCESS}}} +++++((( ", tab, ": ", count:get_stale(tab), " )))+++++++++++++++++++++++++++++++++++++")
    else
           --ngx.log(ngx.ERR, "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ bad happen to signing count['cnt'] to local c, maybe shared count has no count[cnt] {{{ERROR}}} +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++: ", nil)
        count:replace(tab, c + 1)
        ngx.log(ngx.ERR, "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ accumulate ", tab, "{{{SUCCESS}}} +++++((( ", tab, ": ", count:get_stale(tab), " )))+++++++++++++++++++++++++++++++++++++")
    end
end



local cjson = require "cjson"
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000) -- 1 sec
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

-- limit the require
local limit_req = require "resty.limit.req"
local lim, err = limit_req.new("my_limit_req_store", 100, 50)
if not lim then
    ngx.log(ngx.ERR,
            "failed to instantiate a resty.limit.req object: ", err)
    return ngx.exit(500)
end

local key = ngx.var.binary_remote_addr
local delay, err = lim:incoming(key, true)
if not delay then
    if err == "rejected" then
        return ngx.exit(503)
    end
    ngx.log(ngx.ERR, "failed to limit req: ", err)
    return ngx.exit(500)
end

--///////////////////////////////////////////////////////////////////////////////
-- 因为, 第一次请求时候, ngx.shared.body还是空的, 如果这里不进行判断, 则会直接报错, 貌似, access在body_filter前面
-- shared, 没有被清空, 所以要想想办法.
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
local count, err = ngx.shared.count
local c = count:get_stale("cnt")
local c_access = count:get_stale("access_cnt")
local c_body = count:get_stale("body_cnt")

fcount(count, c, "cnt")
fcount(count, c_access, "access_cnt")
ngx.log(ngx.ERR, "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ show body count {{{SUCCESS}}} +++++((( body_cnt: ", count:get_stale("body_cnt"), " )))+++++++++++++++++++++++++++++++++++++")

local body_shared = ngx.shared.body
for i = 1, 40
do
    local id = string.format("body-%d", i)
    red:set(id, body_shared:get(id))
end
--for k, v in pairs(body_shared)
--do
    
--   red:set(k, tostring(v))
--ngx.log(ngx.ERR, "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ show body !!!!!!! {{{SUCCESS}}} +++++((( body: ", k,": ", count:get_stale("body_cnt"), " )))+++++++++++++++++++++++++++++++++++++")

--end


--if count
--then
--     ngx.log(ngx.ERR, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> count {{{SUCCESS}}} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<: ", nil)
--end

--local body_shared = ngx.shared.body
--if body_shared == nil
--then
--    body_shared:set("resp_body", "")
--end
--local value, flags = body_shared:get("resp_body")
--local delay_id = string.format("delay-%s", string.match(tostring(lim), "0x%w+"))
--local body_id = string.format("body-%s", string.match(tostring(lim), "0x%w+"))
-- 这个来看, body_shared的地址是没有变
--local body_shared_addr = string.format("body_chared_addr-%s", string.match(tostring(lim), "0x%w+"))
--local info = cjson.decode(value)
--for k, v in pairs(info)
--do
--    red:set(k, v)
--end
--red:set(body_id, ngx.var.resp_body)
--red:set(body_id, value)
--red:set(body_id, value)
--red:set(delay_id, delay)
--set_by_lua*rewrite_by_lua*access_by_lua*content_by_lua*header_filter_by_lua*body_filter_by_lua*log_by_lua*
--body_shared:flush_all()
--body_shared:flush_expired()
--red:set(body_shared_addr, body_shared)
--///////////////////////////////////////////////////////////////////////////////

if delay >= 0.001 then
    local excess = err
    ngx.sleep(delay)
end
--ngx.sleep(3)
-------------------------

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

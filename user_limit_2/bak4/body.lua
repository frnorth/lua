function fcount(count, c, tab)
    if c == nil then
        count:set(tab, 0)
    else
        count:replace(tab, c + 1)
    end
end

local time = ngx.now()


local count = ngx.shared.count
local body_cnt = count:get_stale("body_cnt")
fcount(count, body_cnt, "body_cnt")

if (string.find(ngx.var.uri, "/user/login"))
then
    local resp_body = ngx.arg[1]
    -- 通过日志可以看到, body_filter 被用了很多次, 因为日志中, 第一次在access.lua打印 body_cnt 到 第二次打印, body_cnt直接增长了 23次
    local body_shared = ngx.shared.body
    local body_id_str = string.format("body-%d", count:get_stale("body_cnt"))
    body_shared:set(body_id_str, tostring(resp_body))
end

local time_cnt = count:get_stale("time_cnt")
if time_cnt == nil then
    count:set("time_cnt", 0)
    time_cnt = 0
end
local time_period = ngx.now() - time
count:replace("time_cnt", time_cnt + time_period)

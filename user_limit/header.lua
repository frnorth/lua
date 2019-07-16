function fcount(count, c, tab)
    if c == nil then
        count:set(tab, 0)
    else
        count:replace(tab, c + 1)
    end
end

local time = ngx.now()

local header_shared = ngx.shared.header
local count = ngx.shared.count
local header_cnt = count:get_stale("header_cnt")
fcount(count, header_cnt, "header_cnt")

local resp_cookie = ngx.header["Set_Cookie"]
if resp_cookie ~= nil
then
    header_shared:set("Set_Cookie", resp_cookie)
end

local time_cnt = count:get_stale("time_cnt")
if time_cnt == nil then
    count:set("time_cnt", 0)
    time_cnt = 0
end
local time_period = ngx.now() - time
count:replace("time_cnt", time_cnt + time_period)
--header_shared:set(string.format("Set_Cookie-%d", count:get_stale("header_cnt")), resp_cookie)

--for k, v in ngx.header
--do
--    header_shared:set(k, v)
--end

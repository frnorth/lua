function fcount(count, c, tab)
    if c == nil then
        count:set(tab, 0)
    else
        count:replace(tab, c + 1)
    end
end


local cjson = require("cjson")
local resp_body = ngx.arg[1]
local count = ngx.shared.count

local c_body = count:get_stale("body_cnt")
-- 通过日志可以看到, body_filter 被用了很多次, 因为日志中, 第一次在access.lua打印 body_cnt 到 第二次打印, body_cnt直接增长了 23次
fcount(count, c_body, "body_cnt")

local body_shared = ngx.shared.body
local body_id_str = string.format("body-%d", count:get_stale("body_cnt"))
body_shared:set(body_id_str, tostring(resp_body))


--local body_str = tostring(resp_body)
--local data = {}
--local name = {}
--name["k"] = "v"

--ngx.log(ngx.ERROR,"----------------------------- ", name["k"])

--if resp_body ~= nil then 
--    local tab_body = cjson.decode(resp_body)
--    data = tab_body["data"]
--end
--
--if data ~= nil then name = data["nick_name"] end
--
--if name ~= nil
--then
--    --ngx.log(ngx.ERROR,"----------------------------- ", cjson.decode(resp_body), " _________________________")
--    ngx.log(ngx.ERROR,"----------------------------- ", name , " _________________________")
--end
--local body_shared = ngx.shared.body
--if body_shared ~= nil
--then
--    body_shared:replace("resp_body", resp_body)
--else
--    body_shared:set("resp_body", resp_body)
--end
-- 这里, 如果用注释的, 就是判断一下ngx.arg[2], 会登陆不上
--if ngx.arg[2] then
--    resp_body_shared:set("resp_body", resp_body)
--end

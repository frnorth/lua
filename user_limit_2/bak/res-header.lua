local redis = require "resty.redis"
local red = redis:new()

red:set_timeout(10000) -- 1 sec

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

--local headers_req, err = ngx.req.get_headers(10)
--
--if err == "truncated" then
--    return
--     -- one can choose to ignore or reject the current request here
--end
--ok, err = red:set("Cookie-req",headers_req["Cookie"])
--if not ok then
--    red:set("Cookie-req", "first cookie")
--    --ngx.say("failed to set Cookie-req: ", err)
--    --return
--end

--local headers_resp, err = ngx.resp.get_headers(10)
--
--if err == "truncated" then
--    --return
--     -- one can choose to ignore or reject the current request here
--end
--ok, err = red:set("Set-Cookie",headers_resp["Set-Cookie"])
--if not ok then
--    --red:set("Set-Cookie", "first cookie")
--    --ngx.say("failed to set Set-Cookie: ", err)
--    --return
--end

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

local redis = require "resty.redis"
local cjson = require "cjson"
local red = redis:new()

red:set_timeout(10000) -- 1 sec

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

--local req, err = ngx.req.get_headers()
--for k, v in pairs(req) do
--    red:set(k, v)
--end

if ngx.var.resp_body ~= nil
then
    red:set("1","1")
end

if ngx.ctx.buffered ~= nil
then
    red:set("2","2")
end

local request_uri = ngx.var.request_uri;
if request_uri == "/user/login/"
then
    red:set("request_uri", request_uri)
    --local body = cjson.decode(ngx.var.resp_body)
    --red:set("body", body)
    --red:set("body_data", body["data"])
    local res, err = ngx.resp.get_headers()
    for k, v in pairs(res) do
        red:set(k, v)
    end
end




--ngx.req.read_body();
--local params = ngx.req.get_post_args();
--if params ~= nil
--then
--  for k,v in ipairs(params) do
--    red:mset(k, v)
--  end
--end


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


--local h, err = ngx.resp.get_headers()
--
--if err == "truncated" then
--    -- one can choose to ignore or reject the current response here
--end
--
--for k, v in pairs(h) do
--    red:set(k, v)
--end



--local res = ngx.location.capture("/user/login/")
--
--if res then
--    red:set("user", res.body)
--end

--res = ngx.location.capture(uri)
--red:set("Set-Cookie", res.header['Set-Cookie'])

--local headers_resp, err = ngx.resp.get_headers(20)
--
----if err == "truncated" then
----    --return
----     -- one can choose to ignore or reject the current request here
----end
--ok, err = red:mset("Cookie-resp",headers_resp["Cookie"])
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

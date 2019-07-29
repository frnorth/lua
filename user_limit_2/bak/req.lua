--print("Hello World!");
--ngx.log(ngx.INFO, " object:", '----->>>>>>>>>>>>>>>')
--ngx.say("Hello World");
local redis = require "resty.redis"
local red = redis:new()

red:set_timeout(10000) -- 1 sec

-- or connect to a unix domain socket file listened
-- by a redis server:
--     local ok, err = red:connect("unix:/path/to/redis.sock")

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local headers, err = ngx.req.get_headers(10)

if err == "truncated" then
    return
     -- one can choose to ignore or reject the current request here
end
ok, err = red:set("Cookie-req",headers["Cookie"])
if not ok then
    red:set("Cookie-req", "first cookie")
    --ngx.say("failed to set Cookie-req: ", err)
    --return
end

--ngx.req.read_body()  -- explicitly read the req body
--local data = ngx.req.get_body_data()
--ok, err = red:set("body", "hehe")
--if not ok then
--    ngx.say("failed to set body: ", err)
--    return
--end

--ok, err = red:set("dog", "an animal")
--if not ok then
--    ngx.say("failed to set dog: ", err)
--    return
--end

--ngx.say("set result: ", ok)

--local res, err = red:get("dog")
--if not res then
--    ngx.say("failed to get dog: ", err)
--    return
--end
--
--if res == ngx.null then
--    ngx.say("dog not found.")
--    return
--end

-- or just close the connection right away:
local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end

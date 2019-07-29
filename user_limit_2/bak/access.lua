
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000) -- 1 sec

local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

local limit_conn = require "resty.limit.conn"
local limit_req = require "resty.limit.req"
local limit_traffic = require "resty.limit.traffic"

local lim1, err = limit_req.new("my_req_store", 20, 10)
assert(lim1, err)
local lim2, err = limit_req.new("my_req_store", 10, 5)
assert(lim2, err)
local lim3, err = limit_conn.new("my_conn_store", 100, 100, 0.5)
assert(lim3, err)

--local lim1, err = limit_req.new("my_req_store", 30, 20)
--assert(lim1, err)
--local lim2, err = limit_req.new("my_req_store", 20, 10)
--assert(lim2, err)
--local lim3, err = limit_conn.new("my_conn_store", 100, 100, 0.5)
--assert(lim3, err)


local limiters = {lim1, lim2, lim3}

local host = ngx.var.host
local client = ngx.var.binary_remote_addr
local keys = {host, client, client}

local states = {}

local delay, err = limit_traffic.combine(limiters, keys, states)
if not delay then
    if err == "rejected" then
        return ngx.exit(503)
    end
    ngx.log(ngx.ERR, "failed to limit traffic: ", err)
    return ngx.exit(500)
end

--local ids = string.format(ngx.ctx)
--local id = string.find(ids, "0x%w")
local ctx = ngx.ctx
for k,v in ipairs(lim3) do
    red:set(k, v)
end

red:set("lim3", lim3)

--red:set("client", client)
--red:set("keys", keys)
--red:set("delay", delay)
--red:set(ngx.ctx, delay)
--red:set(id, delay)
--red:set("ngx.ctx", ngx.ctx)

if lim3:is_committed() then
    local ctx = ngx.ctx
    ctx.limit_conn = lim3
    ctx.limit_conn_key = keys[3]
end

print("sleeping ", delay, " sec, states: ",
      table.concat(states, ", "))

--if delay >= 0.001 then
--    ngx.sleep(delay)
--end

--ngx.sleep(10)

local ok, err = red:close()
if not ok then
    ngx.say("failed to close: ", err)
    return
end




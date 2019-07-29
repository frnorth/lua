local time = ngx.now()

-- 需要被限制的用户, login_name
local name_limit_tab = {
                         "namn1", "wangjie";
                         "name2", "superadmin-wj"
                       }
-- 每5秒允许的操作的上限
local speed1 = 5
local speed2 = 10
local interval = 1

local limit1 = speed1 * interval
local limit2 = speed2 * interval
-- connect the redis ==========================================================================================
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(10000)
local ok, err = red:connect("192.168.1.95", 6380)
if not ok then
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "ERROR in access_by_lua_file failed to connect redis: ", err,
            "\n----------------------------------------\n\n")
    return
end

-- deal the req ==================================================================================================
local h, err = ngx.req.get_headers()
local session = ""
local name = ""
if h ~= nil then
    local coo = h["cookie"]
    if coo ~= nil then
        for k, v in string.gmatch(h["cookie"],"(SESSION)=([^;]+)") do
            session = v;
        end
        if session == nil then
            ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
                    "ERROR in access_by_lua_file session is nil: ", err,
                    "\n----------------------------------------\n\n")
        end
    else
        ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
                "ERROR in access_by_lua_file no cookie in req_header: ", err,
                "\n----------------------------------------\n\n")
    end
else
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "ERROR in access_by_lua_file no req_header: ", err,
            "\n----------------------------------------\n\n")
    -- 调试信息
    --local cooo = string.format("%s-ooooo", coo)
    --for k, v in pairs(h)
    --do
    --    red:hset(cooo, k, v)
    --end
end

-- 调试信息
--ngx.req.read_body()
--local args, err = ngx.req.get_post_args()
--if args ~= nil
--then
--    for key, val in pairs(args) do
--        ngx.log(ngx.ERR, "||||||||||||||||||||| ", key, ": ", val, " cookie: ", session, " ||||||||||||||||||||||||")
--    end
--end

local shared = ngx.shared.shared
if shared ~= nil then
    local value = shared:get(session)
    --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --        "body_num: ", value, "  cookie: ", session,
    --        "\n----------------------------------------\n\n")
    shared:delete(session)
    if value ~= nil then
        local body = ""
        for i = 0, value do
            local session_i = string.format("%s-%d", session, i)
            --red:hset(session, i, tostring(shared:get(session_i)))
            body = body .. tostring(shared:get(session_i))
            shared:delete(session_i)
        end
        for k, v in string.gmatch(body, "\"([%w_%-]*)[\\\"]*:[\\\"]*([%w_%-]*)\"*") do
            red:hset(session, k, v)
        end
        --red:hset(session, "data", body)
        red:expire(session, 14400)
    --else
        --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
        --        "NOTICE in access_by_lua_file no count for body.",
        --        "\n----------------------------------------\n\n")
    end
else
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "ERROR in access_by_lua_file shared memory is nil.",
            "\n----------------------------------------\n\n")
end
if session ~= nil then
    name = red:hget(session, "login_name")
    --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --        name, "  " , ngx.var.uri, "  ", session,
    --        "\n----------------------------------------\n\n")
end

-- time count 统计 access 脚本一共运行了多少时间, 超过30秒, 将共享内存的数据全清空 ==================================================================================================
local time_cnt = shared:get_stale("time_cnt")
if time_cnt == nil then
    shared:set("time_cnt", 0)
    time_cnt = 0
end
if time_cnt > 30 then
    shared:flush_all()
    shared:flush_expired()
end
local time_period = ngx.now() - time
shared:replace("time_cnt", time_cnt + time_period)
red:set("time_period", time_period)
red:set("time_cnt", time_cnt)

-- limit the require =============================================================================================
-- 如果过滤到的名字, 在被限制的表中, stats 为 1
local stats = 0
for k, v in pairs(name_limit_tab) do
    if name == v then
        stats = 1
    end
end

if stats == 1 then

    local name_time_ori = string.format("%s-time-ori", name) -- 起始时间 按 name 命名
    local name_time_last = string.format("%s-time-last", name) -- 上一次记录时间
    local name_act_ave_warn = string.format("%s-act-ave-warn", name) -- 预警值
    local name_act = string.format("%s-act", name) -- 用户操作次数
    --local now = math.floor(ngx.now())
    local now = ngx.now()

    local ori_time = shared:get(name_time_ori)
    if ori_time == nil then
        shared:set(name_time_ori, now)
        ori_time = now
    --else
        --ori_time = math.floor(ori_time)
    end

    local last_time = shared:get(name_time_last)
    if last_time == nil then
        shared:set(name_time_last, 0)
        last_time = 0
    end

    local now_time = now - ori_time

    local period = now_time - last_time
    --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --        "period: ", period,
    --        "\n----------------------------------------\n\n")

    -- 之前认为 act的统计要放在sleep后面, 但是要放在前面, 之前的问题是没有考虑并发而导致的
    -- 并发多线程时候, 10个请求同时拿出act, + 1, 再放回去, 那么act只加了1, 但是本应该 + 10
    local act = shared:get(name_act)
    if act == nil then
        shared:set(name_act, 0)
    else
        act = act + 1
        shared:replace(name_act, act)
    end

    local act_ave_warn = shared:get_stale(name_act_ave_warn)
    if act_ave_warn == nil then
        shared:set(name_act_ave_warn, 0)
        act_ave_warn = 0
    end


    if period >= interval then
        local act_ave = act / period * interval
        --red:hset(name, last_time, act)
        --red:hset(name, math.floor(now_time), math.floor(act_ave))
        red:hset(name, "act_ave_warn", act_ave_warn)
        red:hset(name, math.floor(now_time), act_ave)
        -- 这里不能随便请0, 因为并发1000次请求, 有可能同时又几个请求同时在执行着这个脚本, 将内存中的值清零, 那么其他的执行者的脚本, 就会读取 0 了
        -- nginx 貌似并没有线程安全的问题, 都是单个单个来的, 因为把sleep注释了, 纯统计, 是没有问题的
        shared:replace(name_act, 0)
        -- 如果不加上 *2, 那么因为延迟的误差, 可能会让每5秒操作数为11 12, 这样还是大于max_act_perxs，于是还是会被替换成act_ave, 所以下次sleep就会按照被替换后的act_ave来计算了  
        --if act > (max_act_perxs * 2) then
        --if act_ave > (max_act_perxs * 2) then
        --    shared:replace(name_act_ave_warn, act_ave)
        --end
        --if act_ave > limit2 then
            --act_ave_warn = act_ave_warn + (act_ave -limit2)
        --else
        if act_ave > limit1  then
            act_ave_warn = act_ave_warn + act_ave
        end
        --end
        shared:replace(name_act_ave_warn, act_ave_warn)
        shared:replace(name_time_last, now_time)
    --else
    --    if period < 0.001 then
    --        ngx.log(ngx.ERR, "\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n",
    --                name, "  " , ngx.var.uri, "  ", session, "\n rejected ",
    --                "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n")
    --        ngx.exit(500)
    --    end 
    end
    --ngx.log(ngx.ERR, "\n\n--------------------------------------------------------------------------------\n",
    --        name, "  " , ngx.var.uri, "  ", session, "\n period: ", period,
    --        "\n--------------------------------------------------------------------------------\n\n")


    -- sleep =================================================
    local sleep_time = 0
    if act_ave_warn > limit2 then
        math.randomseed(now)
        sleep_time = math.random() * act_ave_warn / limit2 * interval
    else
        if act_ave_warn > limit1 then
            sleep_time = (act_ave_warn / limit1 - 1) * interval / act_ave_warn
        end
    end
    
    --if act_ave_warn > max_act_perxs then
        --sleep_time = (act_ave_warn / max_act_perxs - 1) * x / act_ave_warn
    --end
    ngx.log(ngx.ERR, "\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n",
            name, "  " , ngx.var.uri, "  ", session, "\nsleep: ", sleep_time, " seconds",
            "\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n\n")
    if sleep_time ~= nil then
        ngx.sleep(sleep_time)
    end
    -- ///////////////////////////////////////////////////////
 

    if now_time >= 150 then
        shared:replace(name_time_ori, now)
        shared:replace(name_time_last, 0)
        red:del(name)
        shared:replace(name_act_ave_warn, 0)
    end
end
-- ////////////////////////////////////////////////////////////////////////////////

local ok, err = red:close()
if not ok then
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "ERROR in access_by_lua_file failed to close redis: ", err,
            "\n----------------------------------------\n\n")
    return
end

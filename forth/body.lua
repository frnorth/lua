-- 共享内存, 名为shared
local shared = ngx.shared.shared
if shared == nil then
    ngx.log(ngx.ERR, "\n----------------------------------------\n",
            "ERROR in body_filter_by_lua_file shared memory is nil.",
            "\n----------------------------------------\n")
    ngx.exit(500)
end

-- 获取响应头
local session = ""
local resp_cookie = ngx.header["Set_Cookie"]
if resp_cookie ~= nil then
    local header_str = tostring(resp_cookie)
    for k, v in string.gmatch(header_str, "(SESSION)=([^;]+)") do
        session = v;
    end
    --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --        "INFO in body_filter_by_lua_file resp_cookie: ", resp_cookie,
    --        "\n----------------------------------------\n\n")
--else
    --ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --        "NOTICE in body_filter_by_lua_file this request has no resp_cookie.",
    --        "\n----------------------------------------\n\n")
end

-- 每次 body_filter 被调用, count +1, key 是本次请求的 session
local count = shared:get_stale(session)
if count == nil then
    local succ, err = shared:set(session, 0)
    -- 调试信息, 看看 count 是否被成功初始化
    --if err then
    --    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
    --            "init count failed", err,
    --            "\n----------------------------------------\n\n")
    --end
    count = 0
else
    count = count + 1
    local succ, err = shared:replace(session, count)
    if err then
        ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
                "increase count failed ", err,
                "\n----------------------------------------\n\n")
    end
end

-- 获取相应体
local resp_body = ngx.arg[1]
if resp_body == nil then
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "resp_body is nil",
            "\n----------------------------------------\n\n")
end

-- 将每一次 body_filter 的相应体放到共享内存中, key 是 本次请求的响应 session-%d, %d 是计数, 每次 body_filter 被调用, +1
local session_count = string.format("%s-%d", session, count)
if session_count == nil then
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "session_count format failed",
            "\n----------------------------------------\n\n")
end

local succ, err = shared:set(session_count, tostring(resp_body))
if err then
    ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
            "set resp_body to shared failed",
            "\n----------------------------------------\n\n")
end

-- 调试信息
--ngx.log(ngx.ERR, "\n\n----------------------------------------\n",
--        session, ": ", count, "\n", session_count, ": \n", shared:get(session_count),
--        "\n----------------------------------------\n\n")

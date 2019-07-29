
local shared = ngx.shared.shared
--local resp_cookie = ngx.header["Set_Cookie"]
--shared:set("kkk", "kkk")
--shared:set("kkkk", resp_cookie)


local resp_cookie = ngx.header["Set_Cookie"]
--local resp_cookie = ngx.resp.get_headers()
--for k, v in pairs(resp_cookie)
--do
--    shared:set(k, v)
--end
local session = ""
if resp_cookie ~= nil
then
    local header_str = tostring(resp_cookie)
    for k, v in string.gmatch(header_str,"(SESSION)=([^;]+)")
    do
        session = v;
    end
end

local count = shared:get_stale(session)
if count == nil
then
    shared:set(session, 0)
    count = 0
else
    count = count + 1
    shared:replace(session, count)
end

local resp_body = ngx.arg[1]
local session_count = string.format("%s-%d", session, count)
shared:set(session_count, tostring(resp_body))


--shared:set(session, )
--local resp_body = ngx.arg[1]
--shared:set(session, tostring(resp_body))


--shared:set("kk", session)
--shared:set(session, "  uuupp")
--local tt = (0, "ooooo")
--shared:set(session, {0, "pp"})
--shared:set(session, tt)


local shared = ngx.shared.shared
local resp_cookie = ngx.header["Set_Cookie"]
local session = ""
if resp_cookie ~= nil
then
    local header_str = tostring(resp_cookie)
    for k, v in string.gmatch(header_str, "(SESSION)=([^;]+)")
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

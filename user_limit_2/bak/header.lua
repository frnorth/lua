local time = ngx.now()

local shared = ngx.shared.shared

local resp_cookie = ngx.header["Set_Cookie"]
local str = tostring(resp_cookie)
if resp_cookie ~= nil
then
    local session = ""
    for k, v in string.gmatch(str,"(SESSION)=([^;]+)")
    do
        session = v;
    end
    shared:set(session, {0, ""})
end

local time_cnt = header_shared:get_stale("time_cnt")
if time_cnt == nil then
    header_shared:set("time_cnt", 0)
    time_cnt = 0
end
local time_period = ngx.now() - time
header_shared:replace("time_cnt", time_cnt + time_period)

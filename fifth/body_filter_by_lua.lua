-- 获取当前的时间
local current_local_time = os.time(os.date('*t'))

-- 删除超时的user_info
local function deleteExpireUserInfo()
	-- 获取当前时间戳-秒
	-- 清理超时的用户信息
	local expire_time_seconds = 8 * 60 * 60
	for session, info in pairs(user_info) do
		if current_local_time - user_info[session]['last_access_time'] > expire_time_seconds then
			user_info[session] = nil
		end
	end
end

-- 获取response数据
local function getResponseBody()
	-- 获取body返回的信息,arg[1]返回数据,arg[2]返回是否结束
	-- 需要使用全局变量多次接受返回的body字符串最终连接起来返回
	local chunk, eof = ngx.arg[1], ngx.arg[2] 
	local buffered = ngx.ctx.buffered 
	if not buffered then 
	   buffered = {}
	   ngx.ctx.buffered = buffered 
	end
	if chunk ~= "" then 
	   buffered[#buffered + 1] = chunk 
	   ngx.arg[1] = nil 
	end
	if eof then
		local response_body = table.concat(buffered) 
		-- 需要使用完整的response_body赋值arg[1]
		ngx.arg[1] = response_body 
		
		-- 接受完数据以后长度可能变化,这两个变量要置空
		ngx.header.content_length = nil
		ngx.header.content_encoding = nil
		return response_body
	end
end

local function getSession()
	-- 获取set-cookie信息,服务器端的session
	local headers = ngx.resp.get_headers()
	local start_i, end_j, session = nil
	if headers['set-cookie'] ~= nil then
		start_i, end_j, session = string.find(headers['set-cookie'], 'SESSION=(%w+)')
	end
	return session
end


-- 存储session->用户信息的k,v信息到user_info全局变量中
-- user_info是共享的变量需要在init中定义
local function saveUserInfo(response_body, session)
	local start, stop, role = string.find(response_body, "\"role\":\"([^\"]+)\"")
	local start, stop, user_id = string.find(response_body, "\"user_id\":(%d+),")
	local start, stop, hospital_id = string.find(response_body, "\"hospital_id\":(%d+),")
	local start, stop, hospital = string.find(response_body, "\"hospital\":\"([^\"]+)\"")
	local start, stop, nick_name = string.find(response_body, "\"nick_name\":\"([^\"]+)\"")
	local start, stop, login_name = string.find(response_body, "\"login_name\":\"([^\"]+)\"")
	user_info[session] = {}	
	user_info[session]['role'] = role
	user_info[session]['user_id'] = user_id
	user_info[session]['hospital_id'] = hospital_id
	user_info[session]['hospital'] = hospital
	user_info[session]['nick_name'] = nick_name
	user_info[session]['last_access_time'] = current_local_time
	user_info[session]['login_name'] = login_name
end


deleteExpireUserInfo()
local uri = ngx.var.uri
--ngx.log(ngx.ERR, uri)
if string.match(uri, "login") then
	--ngx.log(ngx.ERR, '匹配登录接口')
	local response_body = getResponseBody()
	local session = getSession()
	--ngx.log(ngx.ERR, session, '获取到session')
	if response_body and session then
		saveUserInfo(response_body, session)
	end
end

-- 用于限流的 body_filter ===================================================================
-- 共享内存, 名为shared
if string.match(uri, "login") then

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
    end
    
    -- 每次 body_filter 被调用, count +1, key 是本次请求的 session
    local count = shared:get_stale(session)
    if count == nil then
        local succ, err = shared:set(session, 0)
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
end
-- ==========================================================================================

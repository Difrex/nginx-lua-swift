local cjson = require("cjson")
local time = require("os")
local ltn12 = require("ltn12")
local io = require("io")

-- Load configuration
function readConf()
	local file = '/etc/nginx/etc/swift.json'
	local f, err = io.open(file, "rb")
	local content = f:read("*all")
	f:close()

	local conf = cjson.decode(content)
	return conf
end

-- Print nested tables
function content_from_table(tbl)
    for i, v in pairs(tbl) do
        if type(v) == "table" then 
            content_from_table(v)
        else 
            ngx.print(v)
        end
    end
end

-- Write to log
function write_to_logfile(string)
	local conf = readConf('/etc/nginx/etc/swift.json')
	local l, err = io.open(conf.logfile, "a")
	l:write(string .. "\n")
	l:close()
end

local conf = readConf()

-- Make authentication request to Ceph
headers_t = {}
headers_t["X-Auth-User"] = conf.user
headers_t["X-Auth-Key"] = conf.secret_key

local http = require("socket.http")
local r, c, h = http.request{
	url 	= conf.auth_uri,
	headers = headers_t,
	method 	= "GET"
}

-- Return 403 if not authorized 
if c ~= 204 then
    write_to_logfile(time.date() .. ' 403')
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- OK, we get auth token now
local auth_token = ''
auth_token = h["x-auth-token"]

content_headers= {}
content_headers["X-Auth-Token"] = auth_token

write_to_logfile(time.date() .. " Auth OK. Token is: " .. auth_token)


t = {}

local resp, code, http_st = http.request{
	method 	= "GET",
	headers = content_headers,
	url  	= conf.rados_uri .. conf.bucket .. ngx.var.path,
	sink 	= ltn12.sink.table(t)
}

write_to_logfile(time.date() .. " URI: " .. conf.rados_uri .. conf.bucket .. ngx.var.path)

-- Return 404 if object not found in Ceph
if code ~= 200 then
	write_to_logfile(time.date() .. " Not found")
	ngx.exit(ngx.HTTP_NOT_FOUND)
end

-- Print object
content_from_table(t)

-- Feed API - the $12 Server Challenge submission
-- Built with lunet (libuv + LuaJIT coroutine runtime)

package.path = "./app/?.lua;./lib/?.lua;./?.lua;" .. package.path

io.stdout:setvbuf("no")

local lunet = require("lunet")
local socket = require("lunet.socket")
local http = require("http")

local config = require("config")
local db = require("db")
local router = require("router")
require("routes")

local function handle_request(request)
    local status, body = router.handle(request)
    return http.response(status, nil, body)
end

local function handle_client(client)
    -- lib/http.lua reads the supported HTTP/1.1 subset incrementally, then
    -- this server sends one Connection: close response and closes the socket.
    local request, parse_err, parse_status = http.read_request(function()
        return socket.read(client)
    end)
    if not request and not parse_err then
        socket.close(client)
        return
    end
    if not request then
        socket.write(client, http.json_response(parse_status or 400, { error = parse_err }))
        socket.close(client)
        return
    end

    local ok, response = pcall(handle_request, request)
    if not ok then
        io.stderr:write("Request error: ", tostring(response), "\n")
        response = http.json_response(500, { error = "internal server error" })
    end

    socket.write(client, response)
    socket.close(client)
end

lunet.spawn(function()
    local _, open_err = db.connect(config.SQLITE_PATH)
    if open_err then
        print("Failed to open " .. config.SQLITE_PATH .. ": " .. tostring(open_err))
        os.exit(1)
    end

    local listener, listen_err = socket.listen("tcp", config.HOST, config.PORT)
    if not listener then
        print("Failed to listen: " .. tostring(listen_err))
        os.exit(1)
    end

    print("Feed API listening on tcp://" .. config.HOST .. ":" .. config.PORT)

    while true do
        local client = socket.accept(listener)
        if client then
            lunet.spawn(function()
                handle_client(client)
            end)
        end
    end
end)

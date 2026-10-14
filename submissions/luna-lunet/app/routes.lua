local config = require("config")
local db = require("db")
local jwt = require("jwt")
local json = require("lunet.jsonic")
local router = require("router")

local POST_ORDER = { "id", "body", "created_at", "author", "like_count" }

local POST_SELECT = [[
SELECT p.id, p.body, p.created_at, u.username,
       (SELECT count(*) FROM likes l WHERE l.post_id = p.id) AS like_count
  FROM posts p JOIN users u ON u.id = p.user_id
]]

local STARTED_AT = os.time()

local function error_body(message)
    return json.encode({ error = message })
end

local function post_object(row)
    return {
        id = row.id,
        body = row.body,
        created_at = row.created_at,
        author = row.username,
        like_count = row.like_count,
    }
end

local function parse_post_id(raw)
    local id = raw:match("^%d+$") and tonumber(raw)
    if not id or id < 1 then
        return nil
    end
    return id
end

local function authenticate(request)
    local authorization = request.headers["authorization"]
    if not authorization then
        return nil, "missing bearer token"
    end

    local token = authorization:match("^Bearer%s+([^%s]+)$")
    if not token then
        return nil, "missing bearer token"
    end

    local payload = jwt.decode(token, config.JWT_SECRET)
    if not payload then
        return nil, "invalid or expired token"
    end

    local user_id = type(payload.sub) == "string" and payload.sub:match("^%d+$") and tonumber(payload.sub)
    if not user_id or user_id < 1 then
        return nil, "invalid token payload"
    end

    if type(payload.username) ~= "string" then
        return nil, "invalid token payload"
    end

    return { id = user_id, username = payload.username }
end

local function health()
    -- A failed ping is the degraded response, not an internal error
    local ok, err = pcall(db.query, "SELECT 1")
    if not ok then
        return 503, json.encode({ status = "degraded", db = "unreachable", error = err },
            { keyorder = { "status", "db", "error" } })
    end
    return 200, json.encode({ status = "ok", db = "ok", uptime_s = os.time() - STARTED_AT },
        { keyorder = { "status", "db", "uptime_s" } })
end

local function feed()
    local rows = db.query(POST_SELECT .. " ORDER BY p.created_at DESC, p.id DESC LIMIT 20")
    local posts = {}
    for i, row in ipairs(rows) do
        posts[i] = post_object(row)
    end
    return 200, json.encode({ posts = posts }, { keyorder = POST_ORDER })
end

local function show_post(request, params)
    local id = parse_post_id(params.id)
    if not id then
        return 400, error_body("invalid post id")
    end

    local rows = db.query(POST_SELECT .. " WHERE p.id = ?", id)
    if not rows[1] then
        return 404, error_body("post not found")
    end

    return 200, json.encode({ post = post_object(rows[1]) }, { keyorder = POST_ORDER })
end

local function create_post(request)
    local user, auth_error = authenticate(request)
    if not user then
        return 401, error_body(auth_error)
    end

    local payload = json.decode(request.body)
    if type(payload) ~= "table" then
        return 400, error_body("malformed JSON body")
    end

    local body = payload.body
    if type(body) ~= "string" then
        return 400, error_body("body is required")
    end

    body = body:match("^%s*(.-)%s*$")
    if body == "" then
        return 400, error_body("body is required")
    end
    if #body > 500 then
        return 400, error_body("body must be at most 500 characters")
    end

    local rows = db.query("INSERT INTO posts (user_id, body) VALUES (?, ?) RETURNING id, created_at", user.id, body)
    local post = {
        id = rows[1].id,
        body = body,
        created_at = rows[1].created_at,
        author = user.username,
        like_count = 0,
    }
    return 201, json.encode({ post = post }, { keyorder = POST_ORDER })
end

local function like_post(request, params)
    local user, auth_error = authenticate(request)
    if not user then
        return 401, error_body(auth_error)
    end

    local id = parse_post_id(params.id)
    if not id then
        return 400, error_body("invalid post id")
    end

    local existing = db.query("SELECT 1 FROM posts WHERE id = ?", id)
    if not existing[1] then
        return 404, error_body("post not found")
    end

    local result = db.exec("INSERT INTO likes (user_id, post_id) VALUES (?, ?) ON CONFLICT (user_id, post_id) DO NOTHING", user.id, id)
    local already_liked = result.affected_rows == 0
    return already_liked and 200 or 201, json.encode({ liked = true, already_liked = already_liked, post_id = id },
        { keyorder = { "liked", "already_liked", "post_id" } })
end

router.route("GET", "/health", health)
router.route("GET", "/feed", feed)
router.route("GET", "/posts/:id", show_post)
router.route("POST", "/posts", create_post)
router.route("POST", "/posts/:id/like", like_post)

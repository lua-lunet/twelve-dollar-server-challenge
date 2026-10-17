local sqlite = require("lunet.sqlite3")

-- The driver's open returns (rw, ro): writes and any statement that must go
-- through the worker pool run on rw; SELECTs run on ro, inline on the loop
-- thread, uncontended against the single writer in WAL. The pair is cached
-- by the loader on the path, so one open per process.

local db = {}
local conn
local read_conn

function db.connect(path)
    local rw, ro, err = sqlite.open({ path = path })
    if not rw then
        return nil, err
    end
    conn = rw
    read_conn = ro
    _, err = sqlite.exec(conn, "PRAGMA synchronous=NORMAL")
    if err then
        return nil, err
    end
    return true
end

function db.query(sql, ...)
    local target = sql:match("^%s*SELECT") and read_conn or conn
    local rows, err = sqlite.query(target, sql, ...)
    if not rows then
        error(err, 0)
    end
    return rows
end

function db.exec(sql, ...)
    local result, err = sqlite.exec(conn, sql, ...)
    if not result then
        error(err, 0)
    end
    return result
end

return db

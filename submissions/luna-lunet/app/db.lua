local sqlite = require("lunet.sqlite3")

local db = {}
local conn

function db.connect(path)
    local handle, err = sqlite.open({ path = path })
    if not handle then
        return nil, err
    end
    conn = handle
    _, err = sqlite.exec(conn, "PRAGMA synchronous=NORMAL")
    if err then
        return nil, err
    end
    return true
end

function db.query(sql, ...)
    local rows, err = sqlite.query(conn, sql, ...)
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

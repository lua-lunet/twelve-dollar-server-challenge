local sqlite = require("lunet.sqlite3")

-- The driver's open returns (rw, ro); the call sites choose the handle
-- explicitly.

local db = {}
local conn
local read_conn

---Open the cached rw/ro pair on `path`.
---@param path string The SQLite database file
---@return boolean|nil ok true on success; nil with a message on failure
---@return string|nil err The failure message
function db.connect(path)
    local rw, ro, err = sqlite.open({ path = path, synchronous = "NORMAL" })
    if not rw then
        return nil, err
    end
    conn = rw
    read_conn = ro
    return true
end

---Run a statement on the READ-ONLY connection, inline on the main loop.
---FAST PATH ONLY: this blocks the loop for the duration of the query, so
---use it only for WAL reads measured to be fast; anything slow belongs in
---db.query. A write mis-routed here fails loudly with SQLITE_READONLY.
---Prepared statements are not recommended on this path: they would be
---contended.
---@param sql string The SQL statement
---@return table[] rows The result rows
function db.query_ro(sql, ...)
    local rows, err = sqlite.query(read_conn, sql, ...)
    if not rows then
        error(err, 0)
    end
    return rows
end

---Run a statement on the READ-WRITE connection through the worker pool and
---return its result rows (used for writes and for slow query work): the
---work runs single-threaded on the one writer and the caller waits for it,
---leaving the main loop free. Prepared statements are safe here: there is
---a single writer, so a statement is never re-entered while it is in use.
---@param sql string The SQL statement
---@return table[] rows The result rows (writes with RETURNING)
function db.query(sql, ...)
    local rows, err = sqlite.query(conn, sql, ...)
    if not rows then
        error(err, 0)
    end
    return rows
end

---Run a statement on the READ-WRITE connection through the worker pool and
---return the write result (affected rows, last insert id), not result rows.
---@param sql string The SQL statement
---@return table result The write result
function db.exec(sql, ...)
    local result, err = sqlite.exec(conn, sql, ...)
    if not result then
        error(err, 0)
    end
    return result
end

return db

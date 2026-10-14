local sqlite = require("lunet.sqlite3")
local sqlite_ffi = require("sqlite_ffi")

-- Reads ("SELECT ..." statements) run through lib/sqlite_ffi.lua on a separate
-- read-only connection, synchronously on the loop thread. Writes keep the
-- lunet sqlite3 driver. One prepared statement per read sql, made at first use
-- and reused for the life of the process; db.connect resets the cache.

local db = {}
local conn
local read_stmts = {}

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
    local ok, open_err = sqlite_ffi.open(path)
    if not ok then
        return nil, open_err
    end
    read_stmts = {}
    return true
end

function db.query(sql, ...)
    if read_stmts[sql] == nil and sqlite_ffi.is_read(sql) then
        local stmt, prep_err = sqlite_ffi.prepare(sql)
        if not stmt then
            error(prep_err, 0)
        end
        read_stmts[sql] = stmt
    end
    local stmt = read_stmts[sql]
    if stmt then
        local rows, err = sqlite_ffi.query(stmt, ...)
        if not rows then
            error(err, 0)
        end
        return rows
    end
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

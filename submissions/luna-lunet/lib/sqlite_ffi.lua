-- Read-only SQLite via LuaJIT FFI, run synchronously on the loop thread.
-- One extra SQLITE_OPEN_READONLY connection on the same database file as the
-- lunet sqlite3 driver (the write path); WAL readers overlap its writes
-- same-process. Statements are prepared once; each query resets, binds,
-- steps, decodes and resets again — also on error returns, so no statement
-- can leak state between requests.

local ffi = require("ffi")

ffi.cdef[[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef long long sqlite3_int64;
int sqlite3_open_v2(const char *filename, sqlite3 **ppDb, int flags, const char *zVfs);
int sqlite3_close_v2(sqlite3 *db);
const char *sqlite3_errmsg(sqlite3 *db);
int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
int sqlite3_step(sqlite3_stmt *stmt);
int sqlite3_reset(sqlite3_stmt *stmt);
int sqlite3_clear_bindings(sqlite3_stmt *stmt);
int sqlite3_bind_int64(sqlite3_stmt *stmt, int idx, sqlite3_int64 value);
int sqlite3_bind_text(sqlite3_stmt *stmt, int idx, const char *value, int n, void *dtor);
int sqlite3_column_count(sqlite3_stmt *stmt);
const char *sqlite3_column_name(sqlite3_stmt *stmt, int n);
int sqlite3_column_type(sqlite3_stmt *stmt, int n);
sqlite3_int64 sqlite3_column_int64(sqlite3_stmt *stmt, int n);
double sqlite3_column_double(sqlite3_stmt *stmt, int n);
const unsigned char *sqlite3_column_text(sqlite3_stmt *stmt, int n);
int sqlite3_column_bytes(sqlite3_stmt *stmt, int n);
int sqlite3_finalize(sqlite3_stmt *stmt);
]]

local SQLITE_OK = 0
local SQLITE_ROW = 100
local SQLITE_DONE = 101
local SQLITE_INTEGER = 1
local SQLITE_FLOAT = 2
local SQLITE_TEXT = 3
local SQLITE_NULL = 5
local SQLITE_OPEN_READONLY = 1
local SQLITE_TRANSIENT = ffi.cast("void *", -1)

-- macOS arm64 ships /usr/lib/libsqlite3.dylib; Ubuntu 24.04 ships only
-- libsqlite3.so.0 (no unversioned symlink without the banned dev package).
local sqlite
if ffi.os == "OSX" then
    sqlite = ffi.load("sqlite3")
else
    sqlite = ffi.load("sqlite3.so.0")
end

local ffi_db = {}
local db_handle

function ffi_db.open(path)
    local h = ffi.new("sqlite3*[1]")
    local rc = sqlite.sqlite3_open_v2(path, h, SQLITE_OPEN_READONLY, nil)
    if rc ~= SQLITE_OK then
        local msg = rc
        if h[0] ~= nil then
            msg = ffi.string(sqlite.sqlite3_errmsg(h[0]))
            sqlite.sqlite3_close_v2(h[0])
        end
        return false, "sqlite3_open_v2: " .. tostring(msg)
    end
    db_handle = h[0]
    return true
end

function ffi_db.is_read(sql)
    return sql:match("^%s*SELECT") ~= nil
end

function ffi_db.prepare(sql)
    if not db_handle then
        return nil, "sqlite_ffi: no read connection"
    end
    local stmt = ffi.new("sqlite3_stmt*[1]")
    local rc = sqlite.sqlite3_prepare_v2(db_handle, sql, -1, stmt, nil)
    if rc ~= SQLITE_OK or stmt[0] == nil then
        return nil, "sqlite3_prepare_v2: " .. ffi.string(sqlite.sqlite3_errmsg(db_handle))
    end
    local ncols = sqlite.sqlite3_column_count(stmt[0])
    local names = {}
    for i = 0, ncols - 1 do
        names[i] = ffi.string(sqlite.sqlite3_column_name(stmt[0], i))
    end
    return { st = stmt[0], names = names, ncols = ncols }, nil
end

function ffi_db.query(stmt, ...)
    local st = stmt.st
    local names = stmt.names
    local ncols = stmt.ncols
    if sqlite.sqlite3_reset(st) ~= SQLITE_OK then
        sqlite.sqlite3_clear_bindings(st)
        return nil, "sqlite3_reset: " .. ffi.string(sqlite.sqlite3_errmsg(db_handle))
    end
    sqlite.sqlite3_clear_bindings(st)
    local nargs = select("#", ...)
    local k = 0
    while k < nargs do
        k = k + 1
        local v = select(k, ...)
        if type(v) == "number" then
            sqlite.sqlite3_bind_int64(st, k, math.floor(v))
        elseif type(v) == "string" then
            sqlite.sqlite3_bind_text(st, k, v, #v, SQLITE_TRANSIENT)
        else
            sqlite.sqlite3_reset(st)
            sqlite.sqlite3_clear_bindings(st)
            return nil, "sqlite_ffi: unsupported bind type " .. type(v)
        end
    end
    local rows = {}
    local r = 0
    local types = stmt.types
    while true do
        local rc = sqlite.sqlite3_step(st)
        if rc == SQLITE_ROW then
            r = r + 1
            local row = {}
            rows[r] = row
            local rtypes = types
            if rtypes == nil and not stmt.noshape then
                if stmt.cand == nil then
                    local cand = {}
                    local nullable = false
                    for i = 0, ncols - 1 do
                        local t = sqlite.sqlite3_column_type(st, i)
                        cand[i] = t
                        if t == SQLITE_NULL then
                            nullable = true
                        end
                    end
                    if nullable then
                        stmt.noshape = true
                    else
                        stmt.cand = cand
                    end
                else
                    local settled = true
                    for i = 0, ncols - 1 do
                        if sqlite.sqlite3_column_type(st, i) ~= stmt.cand[i] then
                            settled = false
                        end
                    end
                    if settled then
                        types = stmt.cand
                        stmt.types = types
                        rtypes = types
                    else
                        stmt.noshape = true
                    end
                    stmt.cand = nil
                end
            end
            for i = 0, ncols - 1 do
                local ctype = rtypes and rtypes[i] or sqlite.sqlite3_column_type(st, i)
                if ctype == SQLITE_INTEGER then
                    row[names[i]] = tonumber(sqlite.sqlite3_column_int64(st, i))
                elseif ctype == SQLITE_TEXT then
                    row[names[i]] = ffi.string(sqlite.sqlite3_column_text(st, i),
                        sqlite.sqlite3_column_bytes(st, i))
                elseif ctype == SQLITE_FLOAT then
                    row[names[i]] = tonumber(sqlite.sqlite3_column_double(st, i))
                elseif ctype ~= SQLITE_NULL then
                    row[names[i]] = ffi.string(sqlite.sqlite3_column_text(st, i))
                end
            end
        elseif rc == SQLITE_DONE then
            sqlite.sqlite3_reset(st)
            return rows, nil
        else
            local msg = "sqlite3_step: " .. ffi.string(sqlite.sqlite3_errmsg(db_handle))
            sqlite.sqlite3_reset(st)
            sqlite.sqlite3_clear_bindings(st)
            return nil, msg
        end
    end
end

return ffi_db

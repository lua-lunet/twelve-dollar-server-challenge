-- Authentication: bearer-token verification. The signature check is the
-- RFC 2104 HMAC-SHA-256 over the raw key (RFC 7518 section 3.2: a key at or
-- under the 64-byte block size is used as-is) because lunet.security derives
-- 32-byte subkeys for other key lengths, which breaks interop with tokens
-- signed by standard libraries; this verify moves into lunet.security when
-- that lands.

local config = require("config")
local json = require("lunet.jsonic")
local security = require("lunet.security")
local sodium = require("lunet.sodium")
local bit = require("bit")

local auth = {}

local BLOCK = 64

-- RFC 2104 HMAC-SHA-256: H((K xor opad) || H((K xor ipad) || message)).
local function hmac_sha256(key, message)
    if #key > BLOCK then
        key = sodium.sha256(key)
        if not key then return nil end
    end
    local ipad, opad = {}, {}
    for i = 1, BLOCK do
        local b = i <= #key and key:byte(i) or 0
        ipad[i] = bit.bxor(b, 0x36)
        opad[i] = bit.bxor(b, 0x5c)
    end
    local inner = sodium.sha256(string.char(unpack(ipad)) .. message)
    if not inner then return nil end
    return sodium.sha256(string.char(unpack(opad)) .. inner)
end

-- Constant-time equality: the work does not depend on where the bytes
-- first differ.
local function equal(a, b)
    if #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = bit.bor(diff, bit.bxor(a:byte(i), b:byte(i)))
    end
    return diff == 0
end

-- Decode and verify an HS256 JWT. Structural failures (format, base64,
-- signature, header, expired) report one reason; payload TYPE failures are
-- the caller's distinct reason (checked below, per the SPEC's contract).
-- lunet.jsonic decode returns nil + err on invalid JSON (it does not raise),
-- so the pcall results must also be type-checked before indexing.
local function decode(token)
    local header_b64, payload_b64, signature_b64 = token:match("^([^.]+)%.([^.]+)%.([^.]+)$")
    if not header_b64 then
        return nil, "invalid or expired token"
    end

    local sig_ok, signature = pcall(security.crypto.b64url_decode, signature_b64)
    if not sig_ok or not signature then
        return nil, "invalid or expired token"
    end

    local message = header_b64 .. "." .. payload_b64
    local expected = hmac_sha256(config.JWT_SECRET, message)
    if not expected or not equal(signature, expected) then
        return nil, "invalid or expired token"
    end

    local header_ok, header = pcall(json.decode, security.crypto.b64url_decode(header_b64))
    if not header_ok or not header or type(header) ~= "table" or header.alg ~= "HS256" then
        return nil, "invalid or expired token"
    end

    local payload_ok, payload = pcall(json.decode, security.crypto.b64url_decode(payload_b64))
    if not payload_ok or not payload or type(payload) ~= "table" then
        return nil, "invalid or expired token"
    end

    if payload.exp and payload.exp < os.time() then
        return nil, "invalid or expired token"
    end

    return payload
end

-- authenticate(ctx) returns the token owner ({ id, username }) or nil plus
-- the rejection reason for error_body.
function auth.authenticate(ctx)
    local authorization = ctx.headers["authorization"]
    if not authorization then
        return nil, "missing bearer token"
    end

    local token = authorization:match("^Bearer%s+([^%s]+)$")
    if not token then
        return nil, "missing bearer token"
    end

    -- Token content is untrusted input: decode reports structural failures
    -- as nil plus a reason; malformed arguments would be calling bugs.
    local claims = decode(token)
    if not claims then
        return nil, "invalid or expired token"
    end

    local user_id = type(claims.sub) == "string" and claims.sub:match("^%d+$") and tonumber(claims.sub)
    if not user_id or user_id < 1 then
        return nil, "invalid token payload"
    end

    if type(claims.username) ~= "string" then
        return nil, "invalid token payload"
    end

    return { id = user_id, username = claims.username }
end

return auth

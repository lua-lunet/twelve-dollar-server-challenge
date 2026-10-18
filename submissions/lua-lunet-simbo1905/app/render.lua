-- Fixed-shape JSON encode helpers: the response shapes are known, so the
-- byte strings are assembled with static prefixes and one escaper instead of
-- walking tables. The escaper is jsonic's own quotestring (vendored dkjson
-- 2.10), so escaping matches the old encode byte for byte; numbers and
-- booleans are integers/literals here.

local json = require("lunet.jsonic")

local render = {}

function render.jstr(value)
    if type(value) ~= "string" then
        return json.encode(value)
    end
    return json.quotestring(value)
end

function render.jint(value)
    return tostring(value)
end

function render.error_body(message)
    return '{"error":' .. render.jstr(message) .. "}"
end

return render

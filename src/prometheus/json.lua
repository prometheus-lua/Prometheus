-- Small dependency-free JSON codec for source-map files (Lua 5.1 and Luau).
local util = require('prometheus.util')
local Json = {null = {}}
local arrayMeta = {}
function Json.array(value) return setmetatable(value or {}, arrayMeta) end
function Json.isArray(value) return type(value) == 'table' and getmetatable(value) == arrayMeta end

-- Lua strings can contain arbitrary bytes; JSON strings must contain UTF-8
-- Unicode scalars. Reject overlong sequences, surrogates and code points above
-- U+10FFFF, while leaving valid source text byte-for-byte unchanged.
function Json.isValidUtf8(value)
    if type(value) ~= 'string' then return false end
    local index = value:find('[\128-\255]') or #value + 1
    while index <= #value do
        local byte = value:byte(index)
        if byte < 128 then
            index = index + 1
        else
            local length, minimum, maximum = 0, 128, 191
            if byte >= 194 and byte <= 223 then length = 2
            elseif byte >= 224 and byte <= 239 then
                length = 3
                if byte == 224 then minimum = 160 end
                if byte == 237 then maximum = 159 end
            elseif byte >= 240 and byte <= 244 then
                length = 4
                if byte == 240 then minimum = 144 end
                if byte == 244 then maximum = 143 end
            else return false end
            local second = value:byte(index + 1)
            if not second or second < minimum or second > maximum then return false end
            for offset = 2, length - 1 do
                local continuation = value:byte(index + offset)
                if not continuation or continuation < 128 or continuation > 191 then return false end
            end
            index = index + length
        end
    end
    return true
end

local function quote(value)
    assert(Json.isValidUtf8(value), 'Cannot encode JSON string containing invalid UTF-8')
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        if char == '"' then return '\\"' end
        if char == '\\' then return '\\\\' end
        return string.format('\\u%04x', char:byte())
    end) .. '"'
end

function Json.encode(value)
    local active = {}
    local function encode(item)
        if item == Json.null then return 'null' end
        local kind = type(item)
        if kind == 'string' then return quote(item) end
        if kind == 'boolean' then return tostring(item) end
        if kind == 'number' then
            assert(item == item and math.abs(item) ~= math.huge, 'Invalid JSON number')
            return string.format('%.17g', item)
        end
        assert(kind == 'table', 'Unsupported JSON value: ' .. kind)
        assert(not active[item], 'Cyclic JSON value')
        active[item] = true
        local parts = {}
        if getmetatable(item) == arrayMeta then
            for i, child in ipairs(item) do parts[i] = encode(child) end
            active[item] = nil
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local keys = {}
        for key in pairs(item) do
            assert(type(key) == 'string', 'JSON object key must be a string')
            keys[#keys + 1] = key
        end
        table.sort(keys)
        for i, key in ipairs(keys) do parts[i] = quote(key) .. ':' .. encode(item[key]) end
        active[item] = nil
        return '{' .. table.concat(parts, ',') .. '}'
    end
    return encode(value)
end

function Json.decode(input)
    assert(type(input) == 'string', 'JSON input must be a string')
    assert(Json.isValidUtf8(input), 'Invalid JSON: invalid UTF-8')
    local index, depth = 1, 0
    local function fail(message) error('Invalid JSON at byte ' .. index .. ': ' .. message, 0) end
    local function whitespace()
        local _, last = input:find('^[ \t\r\n]*', index)
        index = (last or index - 1) + 1
    end
    local escapes = {['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local function hex()
        local digits = input:sub(index, index + 3)
        if #digits ~= 4 or not digits:match('^%x%x%x%x$') then fail('invalid Unicode escape') end
        index = index + 4
        return tonumber(digits, 16)
    end
    local function stringValue()
        index = index + 1
        local parts = {}
        while index <= #input do
            local char = input:sub(index, index)
            index = index + 1
            if char == '"' then return table.concat(parts) end
            if char == '\\' then
                local escape = input:sub(index, index)
                index = index + 1
                if escape == 'u' then
                    local cp = hex()
                    if cp >= 0xD800 and cp <= 0xDBFF then
                        if input:sub(index, index + 1) ~= '\\u' then fail('missing low surrogate') end
                        index = index + 2
                        local low = hex()
                        if low < 0xDC00 or low > 0xDFFF then fail('invalid low surrogate') end
                        cp = 0x10000 + (cp - 0xD800) * 1024 + low - 0xDC00
                    elseif cp >= 0xDC00 and cp <= 0xDFFF then fail('unexpected low surrogate') end
                    parts[#parts + 1] = util.utf8char(cp)
                elseif escapes[escape] then parts[#parts + 1] = escapes[escape]
                else fail('invalid escape') end
            elseif char:byte() < 32 then fail('unescaped control character')
            else parts[#parts + 1] = char end
        end
        fail('unterminated string')
    end
    local parse
    parse = function()
        whitespace()
        depth = depth + 1
        if depth > 256 then fail('nesting too deep') end
        local char = input:sub(index, index)
        local result
        if char == '"' then result = stringValue()
        elseif char == '[' or char == '{' then
            local isArray, closing = char == '[', char == '[' and ']' or '}'
            result = isArray and Json.array() or {}
            index = index + 1
            whitespace()
            if input:sub(index, index) ~= closing then
                while true do
                    local key
                    if not isArray then
                        if input:sub(index, index) ~= '"' then fail('expected object key') end
                        key = stringValue()
                        whitespace()
                        if input:sub(index, index) ~= ':' then fail('expected colon') end
                        index = index + 1
                    else key = #result + 1 end
                    result[key] = parse()
                    whitespace()
                    local delimiter = input:sub(index, index)
                    if delimiter == closing then break end
                    if delimiter ~= ',' then fail('expected comma or ' .. closing) end
                    index = index + 1
                    whitespace()
                end
            end
            index = index + 1
        elseif input:sub(index, index + 3) == 'true' then index = index + 4; result = true
        elseif input:sub(index, index + 4) == 'false' then index = index + 5; result = false
        elseif input:sub(index, index + 3) == 'null' then index = index + 4; result = Json.null
        else
            local start = index
            if char == '-' then index = index + 1 end
            if input:sub(index, index) == '0' then index = index + 1
            else
                local digits = input:match('^[1-9]%d*', index)
                if not digits then fail('expected value') end
                index = index + #digits
            end
            if input:sub(index, index) == '.' then
                index = index + 1
                local digits = input:match('^%d+', index)
                if not digits then fail('expected fractional digits') end
                index = index + #digits
            end
            if input:sub(index, index):match('[eE]') then
                index = index + 1
                if input:sub(index, index):match('[+-]') then index = index + 1 end
                local digits = input:match('^%d+', index)
                if not digits then fail('expected exponent digits') end
                index = index + #digits
            end
            result = tonumber(input:sub(start, index - 1))
            if not result or math.abs(result) == math.huge then fail('invalid number') end
        end
        depth = depth - 1
        return result
    end
    local result = parse()
    whitespace()
    if index <= #input then fail('trailing input') end
    return result
end

return Json

local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local function pack(...) return {n = select('#', ...), ...} end
local function compile(source, steps, version, seed)
    local generated = Prometheus.Pipeline:fromConfig({
        LuaVersion = version or 'Lua51', Seed = seed or 1,
        Steps = steps or {{Name = 'Vmify'}},
    }):apply(source)
    return assert(loadstring(generated))
end

for _, seed in ipairs({1, 4, 17}) do
    for _, steps in ipairs({{{Name = 'Vmify'}}, {{Name = 'Vmify'}, {Name = 'Cff'}}}) do
        local chunk = compile('return ...', steps, 'Lua51', seed)
        local scalar = compile('return (...)', steps, 'Lua51', seed)
        for _, args in ipairs({pack(), pack(nil), pack(1, nil), pack(nil, 2, nil)}) do
            local result = pack(chunk(unpack(args, 1, args.n)))
            assert(result.n == args.n, 'changed chunk return count')
            for i = 1, args.n do assert(result[i] == args[i], 'changed chunk value') end
            result = pack(scalar(unpack(args, 1, args.n)))
            assert(result.n == 1 and result[1] == args[1], 'parenthesized varargs must collapse')
        end
        local result = pack(compile([[
            local function forward(...) return ... end
            local function invoke(fn, ...) return fn(...) end
            return invoke(forward, nil, 2, nil)
        ]], steps, 'Lua51', seed)())
        assert(result.n == 3 and result[1] == nil and result[2] == 2 and result[3] == nil)
    end
end

-- A true tail call must remain bounded even across distinct virtual prototypes.
local result = pack(compile([[
    local even, odd
    even = function(n) if n == 0 then return true, nil end; return odd(n - 1) end
    odd = function(n) if n == 0 then return false, nil end; return even(n - 1) end
    return even(20000)
]])())
assert(result.n == 2 and result[1] == true and result[2] == nil)

-- Surplus RHS expressions still run, and native list fields flush after keyed fields.
assert(compile([[
    local calls = 0
    local function side() calls = calls + 1; return 3 end
    local a = 1, side(), side() + 1
    local t = {7, [1] = 99, named = true}
    return calls == 2 and a == 1 and t[1] == 7 and t.named
]])())

-- Lower Luau control constructs to portable instructions before emitting Lua.
assert(compile([[
    local sum = 0
    for i = 1, 8 do
        if i % 2 == 0 then continue end
        sum += i
    end
    local value = if sum == 16 then 42 else 0
    return value == 42
]], nil, 'LuaU')())

-- Cff must flatten the interpreter without expanding large prototype data into
-- its dispatcher: doing so can exceed native Lua and LuaJIT branch limits.
local entries = {}
for i = 1, 1000 do entries[i] = tostring(i) end
local source = 'local t={' .. table.concat(entries, ',') .. '}; return t[1],t[1000],...'
local large = compile(source, {{Name = 'Vmify'}, {Name = 'EncryptStrings'}, {Name = 'Cff'}})
local result = pack(large(nil, 3, nil))
assert(result.n == 5 and result[1] == 1 and result[2] == 1000)
assert(result[3] == nil and result[4] == 3 and result[5] == nil)
print('VM arity, tail calls, constructors, and Luau lowering checks passed')

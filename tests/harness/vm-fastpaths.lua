local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Parser = require('prometheus.parser')
local Compiler = require('prometheus.vm.compiler')
local opcodes = require('prometheus.vm.opcodes')
local Presets = require('src.presets')

local function pack(...) return {n = select('#', ...), ...} end
local function difference(left, right, path, seen)
    if type(left) ~= type(right) then return path .. ': type mismatch' end
    if type(left) ~= 'table' then
        if left ~= right then return path .. ': ' .. tostring(left) .. ' ~= ' .. tostring(right) end
        return nil
    end
    seen = seen or {}
    seen[left] = seen[left] or {}
    if seen[left][right] then return nil end
    seen[left][right] = true
    for key, value in pairs(left) do
        local issue = difference(value, right[key], path .. '[' .. tostring(key) .. ']', seen)
        if issue then return issue end
    end
    for key, value in pairs(right) do
        if left[key] == nil and value ~= nil then
            return path .. '[' .. tostring(key) .. ']: extra value ' .. tostring(value)
        end
    end
    return nil
end

local mediumSteps = {}
for i, step in ipairs(Presets.Medium.Steps) do
    mediumSteps[i] = {Name = step.Name, Settings = step.Settings}
end

local function transformed(source, steps, seed, ...)
    local output = Prometheus.Pipeline:fromConfig({
        LuaVersion = 'Lua51', Seed = seed, Steps = steps,
    }):apply(source)
    return assert(loadstring(output))(...)
end

local calls = [[
    local function pack(...) return {n = select('#', ...), ...} end
    local function multi() return 'first', nil, 'third' end
    local function gather(...) return pack(...) end
    local captured = 10
    local function make(step)
        return function(a, b, c)
            captured = captured + step
            return captured, a, b, c
        end
    end
    local closure = make(2)
    local zero = function() return multi() end
    local one = function(a) return a, 'extra' end
    local two = function(a, b) return a, b end
    local three = function(a, b, c) return a, b, c end
    local function oneValue() return 42 end
    local object = {base = 7}
    function object:method(a, b) return self.base, a, b end
    local effects = 0
    local function discarded(...) effects = effects + select('#', ...) end
    discarded('x', nil, 3)
    local scalar = (multi())
    local oneResult = pack(zero())
    local twoResults = pack(two(1))
    local threeResults = pack(three(nil, 2, nil, 'surplus'))
    local method = pack(object:method(nil, 9))
    local expanded = gather(1, 2, gather(3, nil, 5))
    local varargs = gather(...)
    local fourPlus = gather(1, 2, 3, 4, 5, nil)
    local missing = pack(one())
    local surplus = pack(one(8, 9, 10))
    local padA, padB, padC = oneValue()
    local capturedResult = pack(closure(nil, 4))
    local env = getfenv()
    local envs = env == getfenv(nil) and env == getfenv(1)
        and env == getfenv(0) and env == getfenv(function() end)
    return scalar, oneResult, twoResults, threeResults, method, expanded,
        varargs, fourPlus, missing, surplus, pack(padA, padB, padC),
        capturedResult, effects, envs
]]

local assignments = [[
    local function pack(...) return {n = select('#', ...), ...} end
    local trace = {}
    local function mark(value) trace[#trace + 1] = value end
    local target = setmetatable({}, {
        __newindex = function(t, k, v) mark('set:' .. k .. ':' .. tostring(v)); rawset(t, k, v) end,
        __index = function(t, k) mark('get:' .. k); return rawget(t, k) end,
    })
    local function base() mark('base'); return target end
    local function key() mark('key'); return 'a' end
    local i = 1
    local function rhs() mark('rhs'); return 11, 22 end
    base()[key()], base()['b'] = rhs()
    target[i], i = 33, 2
    local first, second = 4, 5
    first, second = second, first
    local duplicate = 0
    duplicate, duplicate = 1, 2
    local alias = setmetatable({}, {__newindex = function(t, k, v)
        mark('alias:' .. v); rawset(t, k, v)
    end})
    alias.x, alias.x = 1, 2
    local ticks = 0
    local function side() ticks = ticks + 1; return ticks end
    local scalar, padded = (side()), side()
    local surplus = 0
    local function ignored() surplus = surplus + 1; return 99 end
    local a = 6, ignored(), ignored()

    local total = 0
    for n = 1, 8 do
        if n % 2 == 0 then
            total = total + n
        else
            total = total + 1
        end
    end
    local r = 0
    repeat r = r + 1 until r == 3
    local g = 0
    for _, value in ipairs({2, 3, 4}) do g = g + value end
    return pack(table.concat(trace, '|'), target.a, target.b, target[1], i,
        first, second, duplicate, alias.x, ticks, scalar, padded, surplus, a, total, r, g)
]]

local controlFlow = [[
    local sum = 0
    local i = 0
    while i < 5 do i = i + 1; if i ~= 3 then sum = sum + i end end
    local j = 0
    repeat j = j + 1; sum = sum + 1 until j == 2
    for n = 1, 5 do if n > 3 then break end; sum = sum + n end
    local k = 0
    for _, value in ipairs({1, 2, 3, 4}) do k = k + value end
    local branch = 'no'
    if sum > 0 then branch = 'yes' end
    return sum, k, branch
]]

local function compare(source, args)
    local expected = pack(assert(loadstring(source))(unpack(args, 1, args.n)))
    for _, seed in ipairs({1, 4, 17}) do
        local actual = pack(transformed(source, {{Name = 'Vmify'}}, seed,
            unpack(args, 1, args.n)))
        local issue = difference(expected, actual, '$')
        assert(not issue, 'Vmify semantic mismatch at seed ' .. seed .. ': ' .. tostring(issue))
        actual = pack(transformed(source, mediumSteps, seed, unpack(args, 1, args.n)))
        issue = difference(expected, actual, '$')
        assert(not issue, 'Medium semantic mismatch at seed ' .. seed .. ': ' .. tostring(issue))
    end
end

for _, args in ipairs({pack(), pack(nil), pack(1, nil), pack(nil, 2, nil),
    pack(1, nil, 3, 4, nil)}) do
    compare(calls, args)
end
compare(assignments, pack())
compare(controlFlow, pack())

-- Make sure representative fixed-arity code actually selects every fast path.
local fixed = [[
    local function r0() end
    local function r1() return 1 end
    local function r2() return 1, nil end
    local function r3() return 1, nil, 3 end
    local function c1(a) return a end
    local function c2(a, b) return a, b end
    local function c3(a, b, c) return a, b, c end
    r0(); c1(1); c2(1, 2); c3(1, 2, 3)
    return 1, 2, 3
]]
local proto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(fixed))
local counts = {}
local namesById = {}
for name, id in pairs(opcodes) do namesById[id] = name end
local function inspect(value)
    for _, instruction in ipairs(value.code) do
        local name = namesById[instruction[1]]
        counts[name] = (counts[name] or 0) + 1
    end
    for _, child in ipairs(value.children) do inspect(child) end
end
inspect(proto)
for arity = 0, 3 do
    assert((counts['CALL' .. arity] or 0) > 0, 'missing CALL' .. arity .. ' fast path')
    assert((counts['RETURN' .. arity] or 0) > 0, 'missing RETURN' .. arity .. ' fast path')
end
assert(not counts.ARGS and not counts.TAKE, 'fixed scalar fixture should not pack result lists')
local assignmentProto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(assignments))
counts = {}
inspect(assignmentProto)
assert((counts.CLEARS or 0) > 0, 'temporary cleanup should batch into CLEARS')

-- A deep tail-call chain also checks that the fixed calls remain tail calls.
local tail = [[
    local even, odd
    even = function(n) if n == 0 then return true, nil end; return odd(n - 1) end
    odd = function(n) if n == 0 then return false, nil end; return even(n - 1) end
    return even(20000)
]]
local result = pack(transformed(tail, {{Name = 'Vmify'}}, 17))
assert(result.n == 2 and result[1] == true and result[2] == nil)
local tailProto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(tail))
counts = {}
inspect(tailProto)
assert((counts.TAILCALL1 or 0) > 0, 'fixed tail recursion should use TAILCALL1')

-- Luau continue is lowered before optimization and must retain its loop target.
local continueSource = [[
    local sum = 0
    for i = 1, 8 do
        if i % 2 == 0 then continue end
        sum += i
    end
    return sum
]]
local continued = Prometheus.Pipeline:fromConfig({LuaVersion = 'LuaU', Seed = 4,
    Steps = {{Name = 'Vmify'}}}):apply(continueSource)
assert(assert(loadstring(continued))() == 16)

-- Informational microbenchmark, with a correctness check and no timing threshold.
local benchmark = [[
    local function add(a, b) return a + b end
    local total = 0
    for i = 1, 3000 do total = total + add(i, 1) end
    return total
]]
local nativeChunk = assert(loadstring(benchmark))
local output = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 17,
    Steps = {{Name = 'Vmify'}}}):apply(benchmark)
local vmChunk = assert(loadstring(output))
local start = os.clock()
local native = nativeChunk()
local nativeSeconds = os.clock() - start
start = os.clock()
local virtual = vmChunk()
local vmSeconds = os.clock() - start
assert(native == virtual)
print(string.format('VM fast-path benchmark: native %.4fs, Vmify %.4fs (3000 fixed calls)',
    nativeSeconds, vmSeconds))
print('VM fast-path behavioral and IR checks passed')

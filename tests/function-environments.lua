local check, get, set = assert, getfenv, setfenv
local globals, select = _G, select
local function pack(...) return {n = select("#", ...), ...} end

Value = 10
local function fixed(delta)
    Value = Value + delta
    return Value
end
local first, second = {Value = 3}, {Value = 30}
check(set(fixed, first) == fixed and get(fixed) == first)
check(fixed(1) == 4 and first.Value == 4 and Value == 10)
set(fixed, second)
check(fixed(2) == 32 and second.Value == 32 and first.Value == 4)

local function variadic(delta, ...)
    Value = Value + delta
    return Value, ...
end
set(variadic, first)
local result = pack(variadic(1, nil, "tail", nil))
check(result.n == 4 and result[1] == 5 and result[2] == nil)
check(result[3] == "tail" and result[4] == nil and Value == 10)

-- Queries through captured aliases and _G report the active call's environment.
local function query()
    return get(), get(nil), get(1), globals.getfenv(1), get(0)
end
set(query, second)
local a, b, c, d, thread = query()
check(a == second and b == second and c == second and d == second)
check(thread == get(0))
local function invoke(fn, ...) return fn(...) end
local function indirectQuery() return invoke(get, 1) end
-- The query belongs to invoke, whose environment differs from its caller's.
set(invoke, first)
set(indirectQuery, second)
check(indirectQuery() == first)

-- New fixed and variadic closures inherit their creator's current environment.
local function maker(delta)
    Value = Value + delta
    return function(extra) Value = Value + extra; return Value end,
           function(...) return Value, ... end
end
set(maker, first)
local child, varargChild = maker(2)
check(get(child) == first and get(varargChild) == first)
set(maker, second)
check(child(1) == 8 and first.Value == 8)
result = pack(varargChild(nil, "child", nil))
check(result.n == 4 and result[1] == 8 and result[2] == nil)
check(result[3] == "child" and result[4] == nil)
check(second.Value == 32 and Value == 10)

-- Nested calls and recursion retain each caller's environment.
local outer, inner
outer = function(depth)
    Value = Value + 1
    if depth > 0 then inner(depth - 1) end
    return Value
end
inner = function(depth)
    Value = Value + 10
    if depth > 0 then outer(depth - 1) end
    return Value
end
set(outer, first)
set(inner, second)
check(outer(2) == 10 and first.Value == 10 and second.Value == 42)

-- Interleaved coroutines retain their environment across suspension.
local yield = coroutine.yield
local function worker()
    Value = Value + 1
    yield(Value)
    Value = Value + 1
    return Value
end
set(worker, first)
local co1 = coroutine.create(worker)
local worker2 = function()
    Value = Value + 10
    yield(Value)
    Value = Value + 10
    return Value
end
set(worker2, second)
local co2 = coroutine.create(worker2)
local ok, value = coroutine.resume(co1)
check(ok and value == 11)
ok, value = coroutine.resume(co2)
check(ok and value == 52)
ok, value = coroutine.resume(co1)
check(ok and value == 12)
ok, value = coroutine.resume(co2)
check(ok and value == 62)
check(Value == 10)

-- Shadowed getters remain ordinary functions; VM helpers keep their builtins.
local original = getfenv
getfenv = function() return "custom" end
check(getfenv(1) == "custom")
local anotherChild = maker(1)
check(get(anotherChild) == second and anotherChild(1) == 64)
getfenv = original

print("OK")

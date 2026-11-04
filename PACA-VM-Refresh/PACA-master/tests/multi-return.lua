--============================================================
-- Multi-Return Test Suite
-- Target: Compiler
-- Author: SpinnySpiwal
-- Purpose: Ensure multi-return behavior is not adversely affected by the new dynamic emission system.
--============================================================

local function half(number)
    local divided = number / 2
    return divided, divided
end

local a, b = half(10)
assert(a == 5 and b == 5, "Test 1 failed: basic multi-return")
print("Test 1 passed: basic multi-return", a, b)

local function mixedReturn()
    return 42, "hello", true, nil
end

local num, str, bool, nilVal = mixedReturn()
assert(num == 42 and str == "hello" and bool == true and nilVal == nil, "Test 2 failed: mixed types")
print("Test 2 passed: mixed types", num, str, bool, nilVal)

local function threeValues()
    return 1, 2, 3
end

local first = threeValues()
assert(first == 1, "Test 3 failed: discarding extra values")
print("Test 3 passed: discarding extra values", first)

local x, y, z, w = threeValues()
assert(x == 1 and y == 2 and z == 3 and w == nil, "Test 4 failed: extra variables get nil")
print("Test 4 passed: extra variables get nil", x, y, z, w)

local function pair()
    return "a", "b"
end

local t1 = { pair() }
assert(t1[1] == "a" and t1[2] == "b", "Test 5 failed: multi-return in table (last)")
print("Test 5 passed: multi-return in table (last)", t1[1], t1[2])

local t2 = { pair(), "c" }
assert(t2[1] == "a" and t2[2] == "c" and t2[3] == nil, "Test 6 failed: multi-return not last")
print("Test 6 passed: multi-return not last", t2[1], t2[2])

local function double(a, b)
    return a * 2, b * 2
end

local d1, d2 = double(threeValues())
assert(d1 == 2 and d2 == 4, "Test 7 failed: nested multi-return")
print("Test 7 passed: nested multi-return", d1, d2)

local function fiveValues()
    return 10, 20, 30, 40, 50
end

local count = select("#", fiveValues())
assert(count == 5, "Test 8 failed: select count")
print("Test 8 passed: select count", count)

local fourth = select(4, fiveValues())
assert(fourth == 40, "Test 9 failed: select specific")
print("Test 9 passed: select specific", fourth)

local function varargReturn(...)
    return ...
end

local v1, v2, v3 = varargReturn(100, 200, 300)
assert(v1 == 100 and v2 == 200 and v3 == 300, "Test 10 failed: vararg return")
print("Test 10 passed: vararg return", v1, v2, v3)

local function sum(a, b, c)
    return (a or 0) + (b or 0) + (c or 0)
end

local result = sum(threeValues())
assert(result == 6, "Test 11 failed: multi-return as arguments")
print("Test 11 passed: multi-return as arguments", result)

print("All multi-return tests passed!")
--============================================================
-- Iteration Test Suite
-- Target: General purpose
-- Author: SpinnySpiwal
-- Purpose: Validate functionality of iterative loops.
-- Note: this test was rewritten after discovering yet another bug in the compiler.
-- The bug was with negative for statements not functioning. And it slipped past the tests.
-- This test ensures this won't happen again.
--============================================================

local TESTS_PASSED = 0
local byte, floor = string.byte, math.floor
local x, y, z, w, t, expected = nil, nil, nil, nil, nil, nil
local function round(value, precision)
    return floor(value * 10^precision) / 10^precision
end

local function str2num(str)
    local result = 0
    for i=1, #str, 1 do
        result = result + byte(str, i)
    end
    return result
end
--============================================================
-- Test 1: Ascending for loop (integer)
--============================================================
y = 0
for _=1, 100 do
    y = y + 1
end

if y ~= 100 then
    print("TEST 1: Ascending for loop (integer) FAILED! Expected 100, got " .. y)
else
    TESTS_PASSED = TESTS_PASSED + 1
end

--============================================================
-- Test 2: Descending for loop (integer)
--============================================================
z = 0
for _=100, 1, -1 do
    z = z + 1
end

if z ~= 100 then
    print("TEST 2: Descending for loop (integer) FAILED! Expected 100, got " .. z)
else
    TESTS_PASSED = TESTS_PASSED + 1
end

--============================================================
-- Test 3: Ascending for loop (float)
--============================================================
w = 0
for _=0, 100, 0.1 do
    w = w + 0.1
end

if round(w, 1) ~= 100 then
    print("TEST 3: Ascending for loop (float) FAILED! Expected 100, got " .. round(w, 1))
else
    TESTS_PASSED = TESTS_PASSED + 1
end

--============================================================
-- Test 4: Descending for loop (float)
--============================================================
w = 0
for _=100, 0, -0.1 do
    w = w + 0.1
end

if round(w, 1) ~= 100 then
    print("TEST 4: Descending for loop (float) FAILED! Expected 100, got " .. round(w, 1))
else
    TESTS_PASSED = TESTS_PASSED + 1
end

--============================================================
-- Test 5: Table iteration (ipairs)
--============================================================
t = {1, 2, 3, 4, 5}
x = 0
expected = 20
for _,v in ipairs(t) do
    x = x + (1+v)
end

if x ~= expected then
    print("TEST 5: Table iteration (ipairs) FAILED! Expected 5, got " .. x)
else
    TESTS_PASSED = TESTS_PASSED + 1
end

--============================================================
-- Test 6: Table iteration (pairs)
-- Note: the test is written this way because the pairs function is not sequential.
-- However, numbers when added together are always the same.
--============================================================
expected = 750
t = {a = 1, b = 2, c = 3, d = 4, e = 5}
y = 0

for k, v in pairs(t) do
    y = y + str2num(k .. v)
end

if y ~= expected then
    print("TEST 6: Table iteration (pairs) FAILED! Expected " .. expected .. ", got " .. y)
else
    TESTS_PASSED = TESTS_PASSED + 1
end

print("TESTS PASSED: " .. TESTS_PASSED .. "/6")
--============================================================
-- Syntax Test Suite
-- Target: Unparser
-- Author: SpinnySpiwal
-- Purpose: Validate appropriate parser & unparser functionality, specifically in unseen edge cases.
-- Update 1: Added test for precedence bug fix in expressionPow.
--============================================================

local char = ("").char
print(char == string.char and "yes" or "no")
local pc, _ = pcall(function()
    return (0).char
end)

-- Checks for unparser bug
print(pc == false and "yes" or "no")
local ok = pcall(function(...)
    print("hello " .. ...)
end)
print(ok and "no" or "yes")

local function getString()
	return "this string is 24 chars!"
end

-- Test for precedence bug fix in expressionPow
if 2 ^ #getString() == 16777216 then
	print("TEST 1 PASSED")
else
	print("TEST 1 FAILED")
end

-- Check if it still works the other way around
if (#getString()) ^ 2 == 576 then
	print("TEST 2 PASSED")
else
	print("TEST 2 FAILED")
end
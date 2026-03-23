--============================================================
-- Syntax Test Suite
-- Target: Unparser
-- Author: SpinnySpiwal
-- Purpose: Validate appropriate unparser functionality, specifically in unseen edge cases.
--============================================================

local char = ("").char
print(char == string.char and "yes" or "no")
local pc, _ = pcall(function()
    return (0)[char]
end)

print(pc == false and "yes" or "no")
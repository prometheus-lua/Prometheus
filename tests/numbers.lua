-- Number emission must preserve values, including folded non-finite results.
local precise = -1.00000000000001
assert(precise == tonumber("-1.00000000000001"))
local large = 1111111111111111
local adjacent = 1111111111111110
assert(large == tonumber("1111111111111111"))
assert(adjacent == tonumber("1111111111111110"))
assert(large - adjacent == 1)

local fraction = 0.12345678901234567
assert(fraction == tonumber("0.12345678901234567"))
local tiny = 1.2345678901234567e-300
local maximum = 1.7976931348623157e308
assert(tiny == tonumber("1.2345678901234567e-300"))
assert(maximum == tonumber("1.7976931348623157e308"))

local positiveInfinity = 10e500
local negativeInfinity = -10e500
assert(positiveInfinity == math.huge)
assert(negativeInfinity == -math.huge)
local nan = 10e500 - 10e400
assert(type(nan) == "number" and nan ~= nan)
assert(not (nan < 0) and not (nan >= 0))
assert(not pcall(function() local t = {}; t[nan] = true end))

print("numbers OK")

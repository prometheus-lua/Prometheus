-- @runtime lua51
-- Negative zero literals and folded expressions keep their sign through Vmify.
local function negativeIntegerZero() return -0 end
local function negativeDecimalZero() return -0.0 end
local function negativeProductZero() return 0 * -1 end
local function positiveZero() return 0 end
local function nestedNegativeZero()
	local function inner() return -0 end
	return inner()
end

assert(1 / negativeIntegerZero() == -math.huge)
assert(1 / negativeDecimalZero() == -math.huge)
assert(1 / negativeProductZero() == -math.huge)
assert(1 / nestedNegativeZero() == -math.huge)
assert(1 / positiveZero() == math.huge)
print('signed zero OK')

local decimal = {1_000, 1__2_, 1_.2_5, .5_0, 1_e+_2_, 2.5e-1, 01, 1.}
local expected = {1000, 12, 1.25, 0.5, 100, 0.25, 1, 1}
for i, value in ipairs(decimal) do assert(value == expected[i]) end

local radix = {0b1010, 0B11, 0b__1__0_, 0_b_1_0_, 0xFF, 0XABCDEF, 0_x_F_F_}
local expectedRadix = {10, 3, 2, 2, 255, 11259375, 255}
for i, value in ipairs(radix) do assert(value == expectedRadix[i]) end

-- Radix conversion rounds once and saturates at the unsigned 64-bit limit.
local boundaries = {
    0x1FFFFFFFFFFFFF, 0x20000000000001, 0x20000000000003,
    0xFFFFFFFFFFFFF800, 0xFFFFFFFFFFFFFFFF,
    0x10000000000000000, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
    0b11111111111111111111111111111111111111111111111111111111111111111,
}
local expectedBoundaries = {
    9007199254740991, 9007199254740992, 9007199254740996,
    18446744073709549568, 18446744073709551616,
    18446744073709551616, 18446744073709551616, 18446744073709551616,
}
for i, value in ipairs(boundaries) do assert(value == expectedBoundaries[i]) end
local overflow, underflow = 1e999, 1e-999
assert(overflow == math.huge and underflow == 0)
assert(1_0 .. 'x' == '10x')
print('Luau numeral checks passed')

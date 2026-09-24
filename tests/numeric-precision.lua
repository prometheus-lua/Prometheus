--!nolint IntegerParsing
--============================================================
-- Numeric Precision & Constant Folding Test Suite
-- Target: Tokenizer, Parser, Ast, Unparser
-- Author: bkkpro1980
-- Purpose: Verify exact numeric literal preservation, safe constant folding, and safe comparison semantics.
--============================================================

local function check(name, actual, expected)
	if actual == expected then
		print(name .. " PASSED")
	else
		print(name .. " FAILED")
		print("expected:", expected)
		print("actual:  ", actual)
	end
end

-- 2^32 must remain distinct from the 32-bit maximum.
local x1 = 0x100000000
local low1 = x1 % 0x100000000
local high1 = math.floor(x1 / 0x100000000)
check("TEST 1", low1 .. "," .. high1, "0,1")

-- Verify that both the high and low 32-bit portions are preserved.
local x2 = 0x100000005
local low2 = x2 % 0x100000000
local high2 = math.floor(x2 / 0x100000000)
check("TEST 2", low2 .. "," .. high2, "5,1")

-- 2^53 - 1 is the largest IEEE-754 safe integer.
local x3 = 0x1FFFFFFFFFFFFF
local low3 = x3 % 0x100000000
local high3 = math.floor(x3 / 0x100000000)
check("TEST 3", low3 .. "," .. high3, "4294967295,2097151")

-- 2^53 is exactly representable and remains distinct from 2^53 - 1.
local x4 = 9007199254740992
local diff4 = x4 - 9007199254740991
local fmt4 = string.format("%.0f", x4)
check("TEST 4", diff4 .. "," .. fmt4, "1,9007199254740992")

-- Standard constant folding should remain enabled for safe expressions.
local add5 = 2 + 3
local mul5 = 10 * 20
local div5 = 12 / 3
local mod5 = 13 % 5
local pow5 = 2 ^ 8
local neg5 = -42
local str5 = "prom" .. "etheus"
local len5 = #"numeric"
check("TEST 5", add5 .. "," .. mul5 .. "," .. div5 .. "," .. mod5 .. "," .. pow5 .. "," .. neg5 .. "," .. str5 .. "," .. len5, "5,200,4,3,256,-42,prometheus,7")

-- Safe integer arithmetic should still be folded.
local fold_large_add = 9007199254740990 + 1
local fold_large_sub = 9007199254740991 - 1
check("TEST 6", string.format("%.0f,%.0f", fold_large_add, fold_large_sub), "9007199254740991,9007199254740990")

-- This product exceeds the safe integer range and must not be incorrectly folded.
local hashProduct = 0x811C9DC5 * 0x01000193
local hashMod = hashProduct % 0x100000000
check("TEST 7", string.format("%.0f,%.0f", hashProduct, hashMod), "36342608889142560,84696352")

-- Inexact division must preserve dyadic fraction precision without assuming (1/3)*3 == 1.
local div_exact = 1000 / 8
local div_half = 7 / 2
local div_eighth = 1 / 8
local ok8 = (div_exact == 125) and (div_half * 2 == 7) and (div_eighth * 8 == 1)
check("TEST 8", ok8, true)

-- `and` and `or` return their operands rather than booleans.
local or1 = false or 123
local or2 = 123 or false
local and1 = true and 456
local and2 = false and 456
local or_nil = nil or "fallback"
local and_str = "left" and "right"
local or_zero = 0 or "unused"
local and_empty = "" and 789
check("TEST 9", tostring(or1) .. "," .. tostring(or2) .. "," .. tostring(and1) .. "," .. tostring(and2) .. "," .. tostring(or_nil) .. "," .. tostring(and_str) .. "," .. tostring(or_zero) .. "," .. tostring(and_empty), "123,123,456,false,fallback,right,0,789")

-- Verify comparisons around the 2^53 boundary.
local c1 = 9007199254740990 < 9007199254740991
local c2 = 9007199254740991 < 9007199254740992
local c3 = 9007199254740991 == 9007199254740991
local c4 = 9007199254740991 ~= 9007199254740992
local c5 = 9007199254740992 > 9007199254740991
local c6 = 9007199254740991 >= 9007199254740991
local c7 = 9007199254740990 <= 9007199254740991
check("TEST 10", c1 and c2 and c3 and c4 and c5 and c6 and c7, true)

-- Mixed-type equality is false; string ordering remains valid.
local eq1 = (5 == "5")
local eq2 = (nil == false)
local eq3 = ("abc" == "abc")
local eq4 = ("abc" ~= "def")
local ord1 = ("apple" < "banana")
local ord2 = ("zebra" > "apple")
check("TEST 11", tostring(eq1) .. "," .. tostring(eq2) .. "," .. tostring(eq3) .. "," .. tostring(eq4) .. "," .. tostring(ord1) .. "," .. tostring(ord2), "false,false,true,true,true,true")

-- A 16-digit float literal must not be truncated to 14 digits by tostring (%.14g).
local f12 = 123456789.0123456
local s12 = string.format("%.7f", f12)
check("TEST 12", s12, "123456789.0123456")

-- 4503599627370497 is 2^52 + 1 (16 decimal digits).
-- Subtraction by 2^52 (4503599627370496) must produce 1 without %.14g collapse.
local x13 = 4503599627370497
local diff13 = x13 - 4503599627370496
check("TEST 13", diff13, 1)

-- Negating a large literal must preserve its value and sign.
local neg_large = -0x100000000
local neg_high = math.floor(neg_large / 0x100000000)
local neg_rem = neg_large % 0x100000000
check("TEST 14", neg_high .. "," .. neg_rem, "-1,0")

-- Safe powers fold at compile-time; powers >= 2^53 remain as runtime expressions.
local pow1 = 2 ^ 16
local pow2 = 2 ^ 32
local pow3 = 2 ^ 53

check(
	"TEST 15",
	pow1 .. "," .. pow2 .. "," .. string.format("%.0f", pow3),
	"65536,4294967296,9007199254740992"
)

-- Large modulo operands must survive NumbersToExpressions without losing precision.
local mod_large1 = 4503599627370497 % 12345
local mod_large2 = 9007199254740000 % 65536
check(
	"TEST 16",
	mod_large1 .. "," .. mod_large2,
	"11177,64544"
)

-- Negative modulo generation must preserve Lua's modulo semantics.
local mod_negative1 = -123456789 % 1000
local mod_negative2 = -4503599627370497 % 12345
check(
	"TEST 17",
	mod_negative1 .. "," .. mod_negative2,
	"211,1168"
)

-- Numbers near the safe-integer boundary must remain exact.
local boundary_pos = 9007199254740991
local boundary_neg = -9007199254740991
check(
	"TEST 18",
	string.format("%.0f,%.0f", boundary_pos, boundary_neg),
	"9007199254740991,-9007199254740991"
)

-- Large hex literals (>53 bits) must round to nearest-even identically to Lua/Luau,
-- even through passes like Vmify that reconstruct numbers without raw text.
local hex_large = 0x2944075f548d8d9
check(
	"TEST 19",
	string.format("%.0f", hex_large),
	"185844359999576288"
)
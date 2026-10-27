local function values(first, last, step)
    local result = {}
    for i = first, last, step do
        assert(type(i) == "number")
        result[#result + 1] = i
    end
    return result
end

local function check(first, last, step, expected)
    local actual = values(first, last, step)
    assert(#actual == #expected)
    for i = 1, #expected do assert(actual[i] == expected[i]) end
end

check("1", 3, 1, {1, 2, 3})
check(1, "3", 1, {1, 2, 3})
check(3, 1, "-1", {3, 2, 1})
check("10", "1", "-2", {10, 8, 6, 4, 2})
check(" 1 ", "3e0", "0x1", {1, 2, 3})
check("3", "1", "1", {})
check("1", "3", "-1", {})

-- Coercion must not overwrite the expressions' source variables.
local first, last, step = "1", "3", "1"
local count = 0
for i = first, last, step do count = count + 1 end
assert(count == 3 and first == "1" and last == "3" and step == "1")

-- Every bound is evaluated once, in order, before validation can fail.
local function invalid(first, last, step)
    local order = {}
    local function bound(position, value)
        order[#order + 1] = position
        return value
    end
    local entered = false
    local ok = pcall(function()
        for i = bound(1, first), bound(2, last), bound(3, step) do
            entered = true
        end
    end)
    assert(not ok and not entered)
    assert(#order == 3 and order[1] == 1 and order[2] == 2 and order[3] == 3)
end

invalid(nil, 1, 1)
invalid(false, 1, 1)
invalid("invalid", 1, 1)
invalid(1, "invalid", 1)
invalid(3, 1, "invalid")

-- Numeric loops reject tables instead of using arithmetic metamethods.
local invoked = false
local object = setmetatable({}, {
    __add = function() invoked = true; return 1 end,
    __sub = function() invoked = true; return 1 end,
    __lt = function() invoked = true; return false end,
    __le = function() invoked = true; return false end,
})
invalid(object, 1, 1)
invalid(1, object, 1)
invalid(1, 1, object)
assert(not invoked)

-- A loop uses its initial values even if bound evaluation or its body changes them.
first = "1"
local function limit() first = "99"; return "3" end
count = 0
for i = first, limit(), "1" do count = count + 1 end
assert(count == 3 and first == "99")
first, last, step = "1", "3", "1"
count = 0
for i = first, last, step do
    count = count + 1
    first, last, step = "99", "0", "-1"
end
assert(count == 3)

local nan = 0 / 0
check(nan, 1, 1, {})
check(1, nan, 1, {})

-- Native numeric loops do not depend on the source program's tonumber global.
local original = tonumber
tonumber = function() error("overridden tonumber called") end
check("1", "3", "1", {1, 2, 3})
tonumber = original

print("OK")

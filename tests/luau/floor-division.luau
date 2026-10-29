local function divide(a, b)
    return a // b
end
assert(divide(7, 2) == 3 and divide(-7, 2) == -4)
assert(divide(7, -2) == -4 and divide(-7, -2) == 3)
assert(divide(7.5, 2) == 3 and divide(-7.5, 2) == -4)
local a, b, c = 29, 3, 2
assert(a // b // c == 4)
assert(a // (b // c) == 29)
assert(a / b // c == 4 and a // b / c == 4.5)
assert(a * b // c % 5 == 3)
assert(2 + a // b * c == 20 and -2 ^ 2 // 3 == -2)
assert(a // b ^ c == 3 and (a // b) ^ c == 81)

-- Preserve IEEE special values and the sign of zero.
local zero, infinity = 0, math.huge
assert(divide(1, zero) == infinity and divide(-1, zero) == -infinity)
local nan = divide(zero, zero)
assert(nan ~= nan)
assert(1 / divide(-zero, 2) == -infinity)
assert(1 / divide(1, -infinity) == -infinity)

-- Floor division uses __idiv, with no fallback to __div or result rounding.
local tag = {}
local meta = {
    __idiv = function(left, right) return tag, 'discarded' end,
    __div = function() error('__div must not handle //') end,
}
local operand = setmetatable({}, meta)
assert(divide(operand, 2) == tag and divide(2, operand) == tag)
assert(select('#', divide(operand, 2)) == 1)
assert(divide('7', 2) == 3)
assert(not pcall(divide, 'invalid', 2))
assert(not pcall(divide, setmetatable({}, {__div = function() return 1 end}), 2))

local value = 20
local function changeValue()
    value = 100
    return 2
end
assert(value // changeValue() == 50)
value = 20
value //= changeValue()
assert(value == 50)
value = 20
local function divideUpvalue()
    return value // changeValue()
end
assert(divideUpvalue() == 10 and value == 100)
value = 50
do
    local function update()
        value //= changeValue()
    end
    update()
    assert(value == 25)
end

floorDivisionGlobal = 20
local function changeGlobal()
    floorDivisionGlobal = 100
    return 2
end
floorDivisionGlobal //= changeGlobal()
assert(floorDivisionGlobal == 10)

local object, calls = {value = 20}, ''
local function base()
    calls ..= 'b'
    return object
end
local function key()
    calls ..= 'k'
    return 'value'
end
local function rhs()
    calls ..= 'r'
    object.value = 100
    return 2
end
base()[key()] //= rhs()
assert(object.value == 10 and calls == 'bkr')

local original = {value = 20}
local replacement = {value = 100}
local holder, index = original, 'value'
holder[index] //= (function()
    holder, index = replacement, 'other'
    return 2
end)()
assert(original.value == 20 and replacement.value == 100 and replacement.other == 10)

local first, second = {value = 20}, {value = 40}
local current = first
local function switchBase()
    current = second
    return 'value'
end
current[switchBase()] //= 2
assert(first.value == 20 and second.value == 20)

local fixedHolder, fixedKey = first, 'value'
local function updateOuterTarget()
    fixedHolder[fixedKey] //= (function()
        fixedHolder, fixedKey = second, 'other'
        return 2
    end)()
end
updateOuterTarget()
assert(first.value == 10 and second.other == nil)
local selfDivision = 7
selfDivision //= selfDivision
assert(selfDivision == 1)

local proxy = setmetatable({}, {
    __index = function(_, key)
        calls ..= 'i'
        return operand
    end,
    __newindex = function(_, key, value)
        assert(value == tag)
        calls ..= 's'
    end,
})
calls = ''
proxy.value //= (function() calls ..= 'r'; return 2 end)()
assert(calls == 'irs')
print('Floor division checks passed')

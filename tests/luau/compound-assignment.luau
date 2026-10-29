-- The shared compound handlers must preserve all existing arithmetic operators.
local value = 20
local function change()
    value = 100
    return 2
end
value += change()
assert(value == 102)
value -= change()
assert(value == 98)
value *= change()
assert(value == 200)
value /= change()
assert(value == 50)
value %= change()
assert(value == 0)
value ^= change()
assert(value == 10000)

local selfValue = 7
selfValue += selfValue
assert(selfValue == 14)
selfValue /= selfValue
assert(selfValue == 1)
selfValue -= selfValue
assert(selfValue == 0)

-- Concatenation snapshots a local before RHS, unlike arithmetic assignment.
local text = 'old'
local function suffix()
    text = 'new'
    return '!'
end
text ..= suffix()
assert(text == 'old!')

local object = {value = 20}
local function changeField()
    object.value = 100
    return 2
end
object.value += changeField()
assert(object.value == 22)
object.value = 20
object.value -= changeField()
assert(object.value == 18)
print('Compound assignment checks passed')

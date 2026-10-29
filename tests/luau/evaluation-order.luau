local value = 20
local function rhs() value = 100; return 50 end
assert(value + rhs() == 150)
value = 20; assert(value - rhs() == 50)
value = 20; assert(value * rhs() == 5000)
value = 20; assert(value / rhs() == 2)
value = 20; assert(value // rhs() == 2)
value = 20; assert(value % rhs() == 0)
value = 20; assert(value ^ rhs() == 1e100)
value = 20; assert(value .. rhs() == '2050')
value = 20; assert(not (value < rhs()))
value = 20; assert(not (value <= rhs()))
value = 20; assert(value > rhs())
value = 20; assert(value >= rhs())
local function equalRhs() value = 100; return 100 end
value = 20; assert(value == equalRhs())
value = 20; assert(not (value ~= equalRhs()))

local function upvalue()
    value = 20
    return value + rhs()
end
assert(upvalue() == 70)
evaluationOrderGlobal = 20
local function globalRhs() evaluationOrderGlobal = 100; return 50 end
assert(evaluationOrderGlobal + globalRhs() == 70)

local first, second = {key = 1}, {key = 2}
local object = first
local function key() object = second; return 'key' end
assert(object[key()] == 2)
local field = 'before'
local function fieldValue() field = 'after'; return 3 end
local constructed = {[field] = fieldValue()}
assert(constructed.before == nil and constructed.after == 3)
print('Luau evaluation order checks passed')

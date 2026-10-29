-- Integer literals require a runtime that supports Luau's integer type.
local exact = 9007199254740993i
assert(type(exact) == 'integer' and exact == 0x20000000000001i)
assert(exact ~= 9007199254740992i)
assert(0xffffffffffffffffi == -1i)
assert(-0xffffffffffffffffi == 1i)
assert(-0x8000000000000000i == 0x8000000000000000i)
assert(0b1111i == 15i and 1_000i == 1000i)
local values = {[exact] = 'exact', [9007199254740992i] = 'other'}
assert(values[exact] == 'exact')
local function valuesFunction() return exact, nil, 9223372036854775807i end
local a, b, c = valuesFunction()
assert(a == exact and b == nil and c == 0x7fffffffffffffffi)
print('Integer literal precision and sign checks passed')

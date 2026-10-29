local function pack(...)
    return {n = select('#', ...), ...}
end
assert(pack(...).n == 0)
local function outer(...)
    local args = pack(...)
    local function fixed() return args.n end
    local function inner(first, ...)
        return first, fixed(), ...
    end
    do
        assert(select('#', ...) == args.n)
    end
    return inner('first', ...)
end
local result = pack(outer(1, nil, 3, nil))
assert(result.n == 6 and result[1] == 'first' and result[2] == 4)
assert(result[3] == 1 and result[4] == nil and result[5] == 3 and result[6] == nil)

local object = {}
function object:collect(...: number)
    return self, ...
end
result = pack(object:collect(1, nil, 2))
assert(result.n == 4 and result[1] == object and result[2] == 1 and result[4] == 2)
local function interpolate(...)
    return `value={(...)}`
end
assert(interpolate(7, 8) == 'value=7')
local function fixed() return 5 end
local function variadic(...) return ... end
assert(fixed() == 5 and select('#', variadic(nil, nil)) == 2)
print('Vararg scope checks passed')

local function prometheus_luau_iterator_1() return 2 end
local sum = prometheus_luau_iterator_1() - 2
local source = {3, 4, 5}
local evaluated = 0
local function tableOnce()
    evaluated += 1
    return source
end
for i, value in tableOnce() do
    if i == 2 then continue end
    sum += i * value
end
local calls = 0
local iterable = setmetatable({}, {
    __iter = function(self)
        calls += 1
        return function(state, control)
            assert(state == 91)
            if control == nil then return false, 11 end
            if control == false then return 2, 21 end
        end, 91, nil
    end,
})
for key, value in iterable do
    sum += value
    if key == false then sum += 1 end
end
local callable = setmetatable({}, {
    __call = function(self, state, key)
        if key == nil then return 1, 9 end
    end,
})
for _, value in callable do sum += value end
local function iteratorFactory()
    return next, {10, 20}, nil
end
for key, value in iteratorFactory() do sum += key + value end
local protected = setmetatable({17}, {__metatable = 'locked'})
for _, value in pairs(protected) do sum += value end
local frozen = table.freeze({1, 2})
for _, value in frozen do sum += value end
local captured = {}
for key, value in {8, 9} do
    captured[#captured + 1] = function() return key, value end
end
local k1, v1 = captured[1]()
local k2, v2 = captured[2]()
print(sum, calls, evaluated, k1, v1, k2, v2)

local t = setmetatable({1}, {
    __metatable = 'locked',
    __iter = function(self) return next, self end,
})
for _, value in t do print(value) end

local iterator = setmetatable({}, {
    __metatable = {},
    __iter = function()
        local i = 0
        return function()
            i += 1
            if i <= 3 then return i, i * 10, nil end
        end
    end,
})
local sum = 0
for i, value in iterator do
    if i == 2 then continue end
    sum += value
end
assert(sum == 40)
local function returning(...)
    for i, value in iterator do
        if i == 2 then return ..., value, nil end
    end
end
local result = table.pack(returning(5, 6))
assert(result.n == 3 and result[1] == 5 and result[2] == 20 and result[3] == nil)
local count = 0
for _ in iterator do count += 1; break end
assert(count == 1)
local function nested()
    for i in iterator do
        for j in iterator do
            if j == 2 then return i, j end
        end
    end
end
local a, b = nested()
assert(a == 1 and b == 2)
local caller
local co = coroutine.create(function()
    caller = coroutine.running()
    for i in iterator do
        assert(coroutine.running() == caller)
        coroutine.yield(i)
    end
end)
for expected = 1, 3 do
    local ok, value = coroutine.resume(co)
    assert(ok and value == expected)
end
assert(coroutine.resume(co))
assert(coroutine.status(co) == 'dead')
print('Protected iterator and callback control checks passed')

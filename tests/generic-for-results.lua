local calls = 0
local state = {}
local function iterator(actualState, control)
    assert(actualState == state)
    calls = calls + 1
    assert(control == calls - 1)
    if control == 0 then return 1, 10, nil, 30, nil, "extra" end
    if control == 1 then return 2, 20, 40 end
    if control == 2 then return 3 end
end

local count = 0
for control, a, b, c, d in iterator, state, 0 do
    count = count + 1
    assert(control == count and d == nil)
    if control == 1 then
        assert(a == 10 and b == nil and c == 30)
    elseif control == 2 then
        assert(a == 20 and b == 40 and c == nil)
    else
        assert(a == nil and b == nil and c == nil)
    end
    -- These assignments cannot affect the internal control or the next results.
    control, a, b, c, d = 99, 99, 99, 99, 99
end
assert(count == 3 and calls == 4)

local function countdown(_, control)
    if control > 0 then return control - 1, nil, control * 10, control * 100 end
end

-- Every iteration gives closures their own cells for every captured result.
local closures = {}
for control, a, b, c, d in countdown, nil, 3 do
    closures[#closures + 1] = function() return control, a, b, c, d end
end
assert(#closures == 3)
for index, closure in ipairs(closures) do
    local control, a, b, c, d = closure()
    assert(control == 3 - index and a == nil and b == (4 - index) * 10)
    assert(c == (4 - index) * 100 and d == nil)
end

-- Fewer declared variables discard extra results without extra iterator calls.
count = 0
for control in countdown, nil, 3 do
    count = count + 1
    assert(control == 3 - count)
end
assert(count == 3)

local captured
for control, a, b, c in countdown, nil, 3 do
    captured = function() return control, a, b, c end
    break
end
local control, a, b, c = captured()
assert(control == 2 and a == nil and b == 30 and c == 300)

local function earlyReturn()
    for control, a, b, c, d in countdown, nil, 3 do
        return control, a, b, c, d
    end
end
local result = {n = select("#", earlyReturn()), earlyReturn()}
assert(result.n == 5 and result[1] == 2 and result[2] == nil)
assert(result[3] == 30 and result[4] == 300 and result[5] == nil)

print("OK")

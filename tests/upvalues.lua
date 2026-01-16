-- Deterministic tests covering closure upvalues in nested functions and loops
local function emitList(label, list)
    print(label .. ":" .. table.concat(list, ","))
end

local function makeSeries(tag)
    local total = 0
    local function step(delta)
        total = total + delta
        return string.format("%s-%d", tag, total)
    end
    local function runSeries(values)
        local out = {}
        for _, delta in ipairs(values) do
            out[#out + 1] = step(delta)
        end
        return out
    end
    return runSeries
end

local alphaSeries = makeSeries("alpha")
emitList("series", alphaSeries({ 1, 2, 1, 3 }))

-- Verify each for-loop iteration captures its own upvalue
local watchers = {}
for i = 1, 4 do
    watchers[i] = function(mult)
        return i * mult
    end
end

for idx, fn in ipairs(watchers) do
    print(string.format("watch%d:%d", idx, fn(idx + 1)))
end

-- Nested functions sharing a master accumulator through for-loops
local function buildAccumulators()
    local master = 0
    local store = {}
    for group = 1, 3 do
        local localTotal = group
        store[group] = function(iterations)
            for step = 1, iterations do
                localTotal = localTotal + group + step
                master = master + group
            end
            return localTotal, master
        end
    end
    return store
end

local runners = buildAccumulators()
for idx, fn in ipairs(runners) do
    local value, master = fn(idx)
    print(string.format("acc%d:%d|%d", idx, value, master))
end

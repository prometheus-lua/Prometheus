-- Indexed targets retain the table and key from before assignment writes.
local t = {}
local original = t
t, t[1] = 0, 42
assert(t == 0 and original[1] == 42)

local index = 1
local values = {}
index, values[index] = 2, 99
assert(index == 2 and values[1] == 99 and values[2] == nil)

local a, i, j, b = {"a", "b"}, 1, 2
b = a
i, a[i], a, j, a[j], a[i+j] = j, i, i, b, j, i
assert(i == 2 and b[1] == 1 and a == 1 and j == b)
assert(b[2] == 2 and b[3] == 1)

-- Evaluate each target component once and before the right-hand values.
local order = {}
local target = {}
local function tableValue()
    order[#order + 1] = "table"
    return target
end
local function keyValue()
    order[#order + 1] = "key"
    return 1
end
local function rhs()
    order[#order + 1] = "rhs"
    target = {}
    return 7
end
original = target
tableValue()[keyValue()] = rhs()
assert(original[1] == 7 and target[1] == nil)
assert(table.concat(order, ",") == "table,key,rhs")

-- Nested assignments also retain captured tables and keys.
local function assignCaptured()
    local tableValue, key = {}, "old"
    local saved = tableValue
    local function assign()
        tableValue, key, tableValue[key] = false, "new", 9
    end
    assign()
    assert(tableValue == false and key == "new")
    assert(saved.old == 9 and saved.new == nil)
end
assignCaptured()

-- Missing results write nil into the captured table after replacing the local.
t = {value = true}
original = t
t, t.value = false
assert(t == false and original.value == nil)

print("OK")

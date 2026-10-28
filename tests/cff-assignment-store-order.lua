-- @runtime lua51
-- Parallel assignments evaluate targets and values first, then store right to left.
local value
value, value = 10, 20
assert(value == 10)

local writes = {}
local proxy = setmetatable({}, {
	__newindex = function(_, key, assigned)
		writes[#writes + 1] = key .. "=" .. assigned
	end,
})
proxy.a, proxy.b, proxy.c = 1, 2, 3
assert(table.concat(writes, ",") == "c=3,b=2,a=1")

local repeated = {}
repeated[1], repeated[1], repeated[1] = 10, 20, 30
assert(repeated[1] == 10)

-- Indexed targets retain their table/key before later target and RHS writes.
local tableValue = {old = 0}
local saved = tableValue
local key = "old"
tableValue, tableValue[key] = {}, 5
assert(tableValue.old == nil and saved.old == 5)

local order = {}
local target = {}
local counter = 0
local function targetKey()
	order[#order + 1] = "lhs"
	counter = counter + 1
	return counter
end
local function rightValue()
	order[#order + 1] = "rhs"
	counter = counter + 1
	return counter
end
target[targetKey()], target[targetKey()] = rightValue(), rightValue()
assert(table.concat(order, ",") == "lhs,lhs,rhs,rhs")
assert(target[1] == 3 and target[2] == 4)

print("OK")

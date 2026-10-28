-- @runtime lua51
-- Discarded expressions in assignment and local initializer lists still run.
local calls = 0
local object = setmetatable({}, {
	__index = function()
		calls = calls + 1
		return 17
	end,
	__add = function()
		calls = calls + 10
		return 23
	end,
})

local first
first = 1, object.missing
assert(calls == 1)

first = 1, object + object
assert(calls == 11)

local ok = pcall(function()
	first = 1, nil + {}
end)
assert(not ok, "discarded operator error must propagate")

local localValue = 1, object.missing
assert(localValue == 1 and calls == 12)

-- A discarded global read must still consult the active function environment.
local originalSetfenv = setfenv
local reads = 0
local env = setmetatable({}, {
	__index = function(_, key)
		if key == "unusedGlobal" then
			reads = reads + 1
			return true
		end
		error("unexpected global lookup: " .. tostring(key), 0)
	end,
})
local function readDiscardedGlobal()
	local value = 1, unusedGlobal
	return value
end
originalSetfenv(readDiscardedGlobal, env)
assert(readDiscardedGlobal() == 1 and reads == 1)

print("OK")

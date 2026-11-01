require("src.prometheus")
local Prometheus = require("src.prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

-- 1. Verify math.random() polyfill behavior
for i = 1, 20 do
	local val = math.random()
	assert(type(val) == "number", "math.random() must return a number")
	assert(val >= 0 and val < 1, "math.random() must be in [0, 1), got " .. tostring(val))
end

local intVal = math.random(10)
assert(intVal >= 1 and intVal <= 10 and intVal == math.floor(intVal), "math.random(10) out of range")

local rangeVal = math.random(5, 15)
assert(rangeVal >= 5 and rangeVal <= 15 and rangeVal == math.floor(rangeVal), "math.random(5, 15) out of range")

local largeVal = math.random(1, 2^40)
assert(largeVal >= 1 and largeVal <= 2^40, "math.random(1, 2^40) out of range")

-- 2. Verify deterministic pipeline with explicit seed
local code = 'local a = 10; local b = 20; return a + b'
local configDeterministic = {
	LuaVersion = "Lua51",
	Seed = 12345,
	NameGenerator = "Mangled",
	Steps = {
		{ Name = "Vmify" },
		{ Name = "EncryptStrings" },
		{ Name = "ConstantArray" },
	}
}

local pipe1 = Prometheus.Pipeline:fromConfig(configDeterministic)
local out1 = pipe1:apply(code, "test.lua")
local pipe2 = Prometheus.Pipeline:fromConfig(configDeterministic)
local out2 = pipe2:apply(code, "test.lua")

assert(out1 == out2, "Configured seed must produce deterministic identical output")
local res1 = assert(loadstring(out1))()
assert(res1 == 30, "Obfuscated code with fixed seed must execute correctly, got " .. tostring(res1))

-- 3. Verify non-deterministic pipeline without configured seed (Seed = 0)
local configRandom = {
	LuaVersion = "Lua51",
	Seed = 0,
	Steps = {
		{ Name = "Vmify" },
		{ Name = "EncryptStrings" },
		{ Name = "ConstantArray" },
	}
}

local randomOutputs = {}
for i = 1, 5 do
	local p = Prometheus.Pipeline:fromConfig(configRandom)
	local o = p:apply(code, "test.lua")
	local res = assert(loadstring(o))()
	assert(res == 30, "Obfuscated code with random seed must execute correctly")
	randomOutputs[i] = o
end

local hasDifference = false
for i = 2, 5 do
	if randomOutputs[i] ~= randomOutputs[1] then
		hasDifference = true
		break
	end
end
assert(hasDifference, "Repeated runs without configured seed must produce different outputs")

print("Random seed and math.random regression checks passed")

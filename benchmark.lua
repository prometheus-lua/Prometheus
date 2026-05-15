local benchmarks = {}

local function add(name, iters, fn)
	benchmarks[#benchmarks+1] = { name = name, iters = iters, fn = fn }
end

-- Arithmetic / numeric loop
add("arithmetic loop", 500000, function(iters)
	local x = 0
	for i = 1, iters do
		x = x + i
	end
	return x
end)

-- Function call overhead
add("function calls", 400000, function(iters)
	local function f(a,b,c) return a + b * c end
	local s = 0
	for i = 1, iters do
		s = s + f(i, 2, 3)
	end
	return s
end)

-- Table creation & insertion
add("table create/insert", 400000, function(iters)
	local last
	for i = 1, iters do
		local t = {i, i*2, i*3}
		t[i % 3 + 1] = i
		last = t
	end
	return last
end)

-- Table iteration (pairs) over fixed table
add("table iteration", 2000, function(iters)
	local t = {}
	for i = 1, 1000 do t[i] = i end
	local s = 0
	for _ = 1, iters do
		for k,v in pairs(t) do
			s = s + v - k
		end
	end
	return s
end)

-- String concatenation (intentional repeated ..)
add("string concat", 4000, function(iters)
	local s = ""
	for i = 1, iters do
		s = s .. "a"
	end
	return #s
end)

-- Closure creation (allocating many small closures)
add("closure creation", 300000, function(iters)
	local acc = 0
	local list = {}
	for i = 1, iters do
		local f = function() return i end
		acc = acc + f()
		list[i % 16] = f -- keep a few alive
	end
	return acc
end)

-- Metatable __index access
add("metatable index", 1000000, function(iters)
	local base = { value = 123 }
	local proxy = {}
	setmetatable(proxy, { __index = base })
	local s = 0
	for i = 1, iters do
		s = s + proxy.value
	end
	return s
end)

local function run(b)
	collectgarbage()
	local start = os.clock()
	b.fn(b.iters)
	local elapsed = os.clock() - start
	return elapsed
end

-- Column widths
local name_w = 4
local iter_w = 10
local time_w = 8
for i = 1, #benchmarks do
	local b = benchmarks[i]
	if #b.name > name_w then name_w = #b.name end
	local ilen = string.len(tostring(b.iters))
	if ilen > iter_w then iter_w = ilen end
end

local function pad(s, w)
	local l = #s
	if l < w then
		return s .. string.rep(" ", w - l)
	end
	return s
end

print("prometheus benchmark")
print(pad("name", name_w) .. "  " .. pad("iterations", iter_w) .. "  time(s)")

local total = 0;
for i = 1, #benchmarks do
	local b = benchmarks[i]
	local t = run(b)
	total = total + t;
	local time_s = string.format("%.6f", t)
	if #time_s > time_w then time_w = #time_s end
	print(pad(b.name, name_w) .. "  " .. pad(tostring(b.iters), iter_w) .. "  " .. time_s)
end

print(pad("total", name_w) .. "  " .. pad("", iter_w) .. "  " .. string.format("%.6f", total))

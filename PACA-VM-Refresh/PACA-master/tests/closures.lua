-- This Test is Part of the Prometheus Obfuscator by levno-710
--
-- closures.lua
--
-- This Test demonstrates deterministic closure behavior.

local arr = {}
for i = 1, 100 do
	local x;
	x = (x or 1) + i;
	arr[i] = function()
		return x;
	end
end

for _, func in ipairs(arr) do
	print(func())
end
-- This Test is Part of the Prometheus Obfuscator by Levno_710
--
-- loops.lua
--
-- This Test demonstrates a simple loop that creates a predictable sequence.

local x = {};
for i = 1, 100 do
    x[i] = i;
end

for i, v in ipairs(x) do
    print("x[" .. i .. "] = " .. v);
end

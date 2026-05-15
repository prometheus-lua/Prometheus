-- This Test is Part of the Prometheus Obfuscator by levno-710
--
-- iterator.lua
--
-- This Test demonstrates a custom iterator that creates a predictable countdown.

local function countdown(startValue, step)
    local value = startValue + step
    return function()
        value = value - step
        if value <= 0 then
            return nil
        end
        return value
    end
end

for num in countdown(12, 3) do
    print(num)
end

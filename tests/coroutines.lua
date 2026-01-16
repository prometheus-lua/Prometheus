-- Deterministic coroutine driven sequence generator
local function squares(limit)
    return coroutine.create(function()
        for i = 1, limit do
            coroutine.yield(i * i)
        end
    end)
end

local co = squares(6)
while true do
    local ok, value = coroutine.resume(co)
    if not ok then
        error(value)
    end
    if value == nil then
        break
    end
    print(value)
end

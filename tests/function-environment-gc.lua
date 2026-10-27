-- @runtime lua51
-- Luau can retain the scoped locals until the surrounding function returns.
local references = setmetatable({}, {__mode = "v"})
do
    local environment = {Value = 1}
    local temporary = function() return Value end
    setfenv(temporary, environment)
    assert(temporary() == 1)
    references[1], references[2] = temporary, environment
end
collectgarbage()
collectgarbage()
assert(references[1] == nil and references[2] == nil)
print("OK")

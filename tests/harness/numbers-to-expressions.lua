local Prometheus = require("src.prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local oldPath = package.path
package.path = "src/?.lua;" .. package.path
local NumbersToExpressions = require("prometheus.steps.NumbersToExpressions")
local Unparser = require("prometheus.unparser")
package.path = oldPath
local unparser = Unparser:new({LuaVersion = "Lua51"})

-- Exercise every representation directly, including recursive/depth-limit paths.
-- Infinity previously produced invalid scientific/hex text or looped in binary.
for _, representation in ipairs({"hex", "binary", "scientific", "normal"}) do
    for _, mutation in ipairs({false, true}) do
        local step = NumbersToExpressions:new({
            InternalThreshold = 0,
            NumberRepresentationMutation = mutation,
            AllowedNumberRepresentations = {representation},
        })
        for _, depth in ipairs({0, 1, 16}) do
            for _, value in ipairs({math.huge, -math.huge, 0/0}) do
                local node = step:CreateNumberExpression(value, depth)
                local code = unparser:unparseExpression(node, 0)
                local actual = assert(loadstring("return " .. code))()
                assert(type(actual) == "number", representation .. ": " .. code)
                if value ~= value then
                    assert(actual ~= actual, representation .. ": lost NaN")
                else
                    assert(actual == value, representation .. ": changed infinity")
                end
            end
        end
    end
end
print("Non-finite number mutation regression checks passed")

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

-- Hex formatting has a host-dependent integer range; overflow must preserve
-- the original number. Also check ordinary hex values still work.
local hex = NumbersToExpressions:new({
    InternalThreshold = 0,
    NumberRepresentationMutation = true,
    AllowedNumberRepresentations = {"hex"},
})
for _, value in ipairs({0, 255, 2^32, 2^53, 2^63, 2^64, 1.23e30, 1.7976931348623157e308}) do
    local code = unparser:unparseExpression(hex:CreateNumberExpression(value, 1), 0)
    assert(assert(loadstring("return " .. code))() == value, "hex mutation changed " .. tostring(value))
end
assert(type(hex:CreateNumberExpression(255, 1).value) == "string", "ordinary hex mutation was disabled")

local config = {LuaVersion = "Lua51", Seed = 1, Steps = {{Name = "NumbersToExpressions", Settings = {
    NumberRepresentationMutation = true,
    AllowedNumberRepresentations = {"hex"},
}}}}
local generated = Prometheus.Pipeline:fromConfig(config):apply('local n = 1.23e30; assert(n == tonumber("1.23e30"))')
assert(loadstring(generated))()
print("Number mutation regression checks passed")

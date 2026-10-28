local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Parser = require('prometheus.parser')
local Compiler = require('prometheus.vm.compiler')
local Emit = require('prometheus.vm.emit')
local opcodes = require('prometheus.vm.opcodes')

local source = [[
    local function negativeIntegerZero() return -0 end
    local function negativeDecimalZero() return -0.0 end
    local function negativeProductZero() return 0 * -1 end
    local function positiveZero() return 0 end
    local function nestedNegativeZero()
        local function inner() return -0 end
        return inner()
    end
    assert(1 / negativeIntegerZero() == -math.huge)
    assert(1 / negativeDecimalZero() == -math.huge)
    assert(1 / negativeProductZero() == -math.huge)
    assert(1 / nestedNegativeZero() == -math.huge)
    assert(1 / positiveZero() == math.huge)
]]

local proto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(source))
local negativeZeroLoads = 0
local function checkPrototype(value)
    for _, constant in ipairs(value.constants) do
        assert(not (type(constant) == 'number' and constant == 0 and 1 / constant < 0),
            'VM prototype must not contain a negative-zero literal')
    end
    for _, instruction in ipairs(value.code) do
        if instruction[1] == opcodes.NEG then negativeZeroLoads = negativeZeroLoads + 1 end
    end
    for _, child in ipairs(value.children) do checkPrototype(child) end
end
checkPrototype(proto)
assert(negativeZeroLoads >= 4, 'negative-zero literals must lower to VM NEG in their prototypes')

assert(loadstring(Emit.source(proto)))()
print('VM signed-zero checks passed')

for _, preset in ipairs({'Cff', 'Weak'}) do
    for _, seed in ipairs({1, 2, 17}) do
        local config = require('src.presets')[preset]
        config.Seed = seed
        local generated = Prometheus.Pipeline:fromConfig(config):apply(source)
        assert(loadstring(generated))()
    end
end

-- Keep more than MAX_REGS locals live so the negative-zero register spills.
local locals, checks = {}, {}
for i = 1, 130 do
    locals[i] = 'local value' .. i .. '=' .. i
    checks[i] = 'assert(value' .. i .. '==' .. i .. ')'
end
local spillSource = table.concat(locals, '\n') .. [[
    local negative = -0
    assert(1 / negative == -math.huge)
]] .. table.concat(checks, '\n')
for _, preset in ipairs({'Cff', 'Weak'}) do
    for _, seed in ipairs({1, 2, 17}) do
        local config = require('src.presets')[preset]
        config.Seed = seed
        local generated = Prometheus.Pipeline:fromConfig(config):apply(spillSource)
        assert(loadstring(generated))()
    end
end
print('Cff signed-zero and spill checks passed')

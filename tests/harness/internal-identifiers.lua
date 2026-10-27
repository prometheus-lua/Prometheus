local Prometheus = require('src.prometheus')
local Parser = require('prometheus.parser')
local logger = Prometheus.Logger

local originalWarn, originalLevel = logger.warnCallback, logger.logLevel
local warnings = {}
logger.logLevel = logger.LogLevel.Warn
logger.warnCallback = function(message) warnings[#warnings + 1] = message end

local function prefixWarnings()
    local count = 0
    for _, message in ipairs(warnings) do
        if message:find('identifiers should not start', 1, true) then count = count + 1 end
    end
    return count
end

local ok, err = pcall(function()
    local source = 'local __prometheus_example = 1; return __prometheus_example'
    local parser = Parser:new({LuaVersion = 'Lua51'})
    parser:parse(source)
    assert(prefixWarnings() == 2, 'User identifiers must still warn by default')

    warnings = {}
    Parser:new({LuaVersion = 'Lua51', AllowInternalIdentifiers = false}):parse(source)
    assert(prefixWarnings() == 2, 'Explicit false must preserve reserved-prefix warnings')

    warnings = {}
    local internal = Parser:new({LuaVersion = 'Lua51', AllowInternalIdentifiers = true})
    internal:parse(source)
    assert(#warnings == 0, 'Internal identifiers must not warn')
    internal:parse('local __prometheus_example = 1, 2')
    assert(prefixWarnings() == 0 and #warnings == 1
        and warnings[1]:find('assigning 2 values to 1 variable', 1, true),
        'Internal parsing must preserve unrelated warnings')

    warnings = {}
    parser:parse(source)
    assert(prefixWarnings() == 2, 'Internal parsing must not change other parser instances')

    for _, exclude in ipairs({true, false}) do
        warnings = {}
        local output = Prometheus.Pipeline:fromConfig({
            LuaVersion = 'Lua51', Seed = 1,
            Steps = {{Name = 'Vmify'}, {Name = 'Cff', Settings = {ExcludeVm = exclude}}},
        }):apply('local value = ...; return value + 1, nil')
        assert(prefixWarnings() == 0, 'Cff generated-code parsing emitted reserved-prefix warnings')
        local chunk = assert(loadstring(output))
        assert(select('#', chunk(41)) == 2 and chunk(41) == 42,
            'Cff generated-code parsing changed runtime results')
    end
end)

logger.warnCallback, logger.logLevel = originalWarn, originalLevel
assert(ok, err)
print('Internal identifier diagnostics passed')

local Prometheus = require('src.prometheus')
local Parser = require('prometheus.parser')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
Prometheus.Logger.errorCallback = function(message) error(message, 0) end

for _, version in ipairs({'Lua51', 'LuaU'}) do
    for _, ending in ipairs({'\n', '\r', '\r\n', '\n\r'}) do
        for _, steps in ipairs({{}, {{Name = 'Cff'}}, {{Name = 'Vmify'}}}) do
            local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = version, Seed = 17, Steps = steps})
            local source = 'return "a\\' .. ending .. 'b"'
            if version == 'LuaU' and ending == '\n\r' then
                assert(not pcall(function() pipeline:apply(source) end))
            else
                assert(assert(loadstring(pipeline:apply(source)))() == 'a\nb')
            end
            local source = '-- comment' .. ending .. 'return 42'
            assert(assert(loadstring(pipeline:apply(source)))() == 42)
        end
        local parser = Parser:new({LuaVersion = version})
        assert(not pcall(function() parser:parse('return "a' .. ending .. 'b"') end))
        local ok, message = pcall(function() parser:parse('-- comment' .. ending .. 'local x = "\\u{110000}"') end)
        assert(not ok and tostring(message):find('Position 2:', 1, true))
        assert(parser:parse('return "valid"'))
    end
end
for _, name in ipairs({'Minify', 'Cff', 'Vmify', 'Weak', 'Medium', 'Strong'}) do
    local config = {}
    for key, value in pairs(Prometheus.Presets[name]) do config[key] = value end
    config.LuaVersion, config.Seed = 'LuaU', 17
    local output = Prometheus.Pipeline:fromConfig(config):apply('--!native\r\n--!optimize 1\nreturn 42')
    local prefix = '--!native\n--!optimize 1\n'
    assert(output:sub(1, #prefix) == prefix)
end
print('String normalization, diagnostics, and directive checks passed')

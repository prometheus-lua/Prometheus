-- Parse a corpus without executing it, then emit the type-erased AST.
local Prometheus = require('src.prometheus')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
Prometheus.Logger.errorCallback = function(message) error(message, 0) end
math.randomseed(1)

for path in assert(io.open(arg[1], 'r')):lines() do
    local file = assert(io.open(path, 'rb'))
    local source = file:read('*a')
    file:close()
    local ok, message = pcall(function()
        local ast = Parser:new({LuaVersion = 'LuaU'}):parse(source)
        local generated = Unparser:new({LuaVersion = 'LuaU'}):unparse(ast)
        local output = assert(io.open(path .. '.out.luau', 'wb'))
        output:write(generated)
        output:close()
    end)
    io.write(ok and 'accept' or 'reject', '\t', ok and '' or tostring(message):gsub('[\r\n\t]', ' '), '\n')
end

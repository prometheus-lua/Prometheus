local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Parser = require('prometheus.parser')
local Compiler = require('prometheus.vm.compiler')
local Emit = require('prometheus.vm.emit')
local opcodes = require('prometheus.vm.opcodes')

-- Editing instruction operands changes execution: the emitted tables are executable
-- program data, rather than metadata alongside a native copy of the source body.
local ast = Parser:new({LuaVersion = 'Lua51'}):parse('return 17')
local proto = Compiler:compile(ast)
local changed = false
for _, instruction in ipairs(proto.code) do
    if instruction[1] == opcodes.LOAD and proto.constants[instruction[3]] == 17 then
        proto.constants[instruction[3]] = 42
        changed = true
    end
end
assert(changed)
assert(assert(loadstring(Emit.source(proto)))() == 42)
proto.code[1][1] = 1000000
local ok, err = pcall(assert(loadstring(Emit.source(proto))))
assert(not ok and tostring(err):find('unknown VM opcode', 1, true))

-- Cells capture only the requested lexical locals, including transitive captures.
local source = [[
    local shared, unused = 0, {}
    return function()
        return function(delta) shared = shared + delta; return shared end
    end
]]
local proto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(source))
local maker = assert(loadstring(Emit.source(proto)))()
local first, second = maker(), maker()
assert(first(2) == 2 and second(3) == 5 and first(4) == 9)
assert(#proto.children[1].captures == 1)
assert(#proto.children[1].children[1].captures == 1)
print('VM prototype execution and transitive capture checks passed')

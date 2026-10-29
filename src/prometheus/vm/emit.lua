-- Emit scattered data, startup reconstruction, and a generated interpreter.
local Parser = require('prometheus.parser')
local Enums = require('prometheus.enums')
local Runtime = require('prometheus.vm.runtime')
local Layout = require('prometheus.vm.layout')
local Data = require('prometheus.vm.data')
local Emit = {}

function Emit.source(proto, layout)
    layout = layout or Layout.new()
    local data, tables, root = Data.encode(proto, layout)
    local initializer = 'rebuild(' .. data .. ',' .. tables .. ',' .. root .. ')'
    local source, count = Runtime.build(layout):gsub('__PROTOTYPES__', function() return initializer end)
    assert(count == 1, 'Runtime template must contain one prototype marker')
    return Data.rebuild .. source
end

function Emit.ast(proto)
    local ast = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(Emit.source(proto))
    local invocation = ast.body.statements[#ast.body.statements].args[1]
    ast.vmRuntime = invocation.base
    -- Only the large shard literal stays native. Cff protects the reconstruction call/helper.
    ast.vmData = invocation.args[1].args[1]
    return ast
end

return Emit

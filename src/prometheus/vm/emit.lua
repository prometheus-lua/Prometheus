-- Emit native table data and a generated interpreter, then parse the complete AST.
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local Enums = require('prometheus.enums')
local Runtime = require('prometheus.vm.runtime')
local Layout = require('prometheus.vm.layout')
local Emit = {}

function Emit.source(proto, layout)
    layout = layout or Layout.new()
    local unparser = Unparser:new({LuaVersion = Enums.LuaVersion.Lua51})
    local function literal(value)
        if type(value) ~= 'table' then
            return unparser:unparseExpression(Ast.ConstantNode(value), 0)
        end
        local parts = {}
        for _, entry in ipairs(value) do parts[#parts + 1] = literal(entry) end
        return '{' .. table.concat(parts, ',') .. '}'
    end
    local function prototype(value)
        local instructions = {}
        for _, instruction in ipairs(value.code) do
            local encoded, length = layout:encode(instruction)
            local operands = {}
            for slot = 1, length do operands[slot] = literal(encoded[slot]) end
            instructions[#instructions + 1] = '{' .. table.concat(operands, ',') .. '}'
        end
        local parts = {'code={' .. table.concat(instructions, ',') .. '}'}
        for _, key in ipairs({'constants', 'captures', 'params', 'vararg', 'maxRegister'}) do
            parts[#parts + 1] = key .. '=' .. literal(value[key])
        end
        local children = {}
        for _, child in ipairs(value.children) do children[#children + 1] = prototype(child) end
        parts[#parts + 1] = 'children={' .. table.concat(children, ',') .. '}'
        return '{' .. table.concat(parts, ',') .. '}'
    end
    local data = '{' .. prototype(proto) .. '}'
    local source, count = Runtime.build(layout):gsub('__PROTOTYPES__', function() return data end)
    assert(count == 1, 'Runtime template must contain one prototype marker')
    return source
end

function Emit.ast(proto)
    local ast = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(Emit.source(proto))
    ast.vmRuntime = ast.body.statements[1].args[1].base
    ast.vmData = ast.body.statements[1].args[1].args[1]
    return ast
end

return Emit

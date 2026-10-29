-- Emit native table data and a generated interpreter, then parse the complete AST.
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local Enums = require('prometheus.enums')
local Runtime = require('prometheus.vm.runtime')
local Layout = require('prometheus.vm.layout')
local opcodes = require('prometheus.vm.opcodes')
local Emit = {}

local function usesNativeLuau(proto)
    for _, value in ipairs(proto.constants) do
        if type(value) == 'table' and (value.isNativeLuau or value.kind == Ast.AstKind.IntegerExpression) then return true end
    end
    for _, child in ipairs(proto.children) do if usesNativeLuau(child) then return true end end
    return false
end

local function usesFloorDivision(proto)
    for _, instruction in ipairs(proto.code) do
        if instruction[1] == opcodes.IDIV then return true end
    end
    for _, child in ipairs(proto.children) do
        if usesFloorDivision(child) then return true end
    end
    return false
end

function Emit.source(proto, layout)
    layout = layout or Layout.new()
    local unparser = Unparser:new({LuaVersion = Enums.LuaVersion.LuaU})
    local function literal(value)
        if type(value) == 'table' and (value.isNativeLuau or value.kind == Ast.AstKind.IntegerExpression) then return unparser:unparseExpression(value, 0) end
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
    local source, count = Runtime.build(layout, usesFloorDivision(proto)):gsub('__PROTOTYPES__', function() return data end)
    assert(count == 1, 'Runtime template must contain one prototype marker')
    return source
end

function Emit.ast(proto)
    local version = (usesFloorDivision(proto) or usesNativeLuau(proto)) and Enums.LuaVersion.LuaU or Enums.LuaVersion.Lua51
    local ast = Parser:new({LuaVersion = version}):parse(Emit.source(proto))
    ast.vmRuntime = ast.body.statements[1].args[1].base
    ast.vmData = ast.body.statements[1].args[1].args[1]
    if usesNativeLuau(proto) then
        local visitast = require('prometheus.visitast')
        visitast(Ast.TopNode(Ast.Block({Ast.ReturnStatement{ast.vmData}}, ast.body.scope), ast.globalScope), function(node)
            if node.kind == Ast.AstKind.FunctionLiteralExpression then node.isNativeLuau = true; return nil, true end
        end)
    end
    return ast
end

return Emit

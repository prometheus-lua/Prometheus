-- Emit native table data and a generated interpreter, then parse the complete AST.
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local Enums = require('prometheus.enums')
local Runtime = require('prometheus.vm.runtime')
local Emit = {}

function Emit.source(proto)
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
        local parts = {}
        for _, key in ipairs({'code', 'constants', 'captures', 'params', 'vararg', 'maxRegister'}) do
            parts[#parts + 1] = key .. '=' .. literal(value[key])
        end
        local children = {}
        for _, child in ipairs(value.children) do children[#children + 1] = prototype(child) end
        parts[#parts + 1] = 'children={' .. table.concat(children, ',') .. '}'
        return '{' .. table.concat(parts, ',') .. '}'
    end
    local data = '{' .. prototype(proto) .. '}'
    local source, count = Runtime.build():gsub('__PROTOTYPES__', function() return data end)
    assert(count == 1, 'Runtime template must contain one prototype marker')
    return source
end

function Emit.ast(proto)
    local ast = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(Emit.source(proto))
    ast.vmRuntime = ast.body.statements[1].args[1].base
    return ast
end

return Emit

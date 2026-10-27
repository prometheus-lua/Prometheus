-- Flatten a generated interpreter without virtualizing its large data initializer.
local Ast = require('prometheus.ast')
local Scope = require('prometheus.scope')
local visitast = require('prometheus.visitast')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local CffCompiler = require('prometheus.cff.compiler')
local Enums = require('prometheus.enums')

local function externalVariables(ast, runtime)
    local owned, variables, seen = {}, {}, {}
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})},
        Scope:new(ast.globalScope)), ast.globalScope)
    visitast(wrapper, function(node)
        if node.kind == 'Block' then owned[node.scope] = true end
    end)
    local writes = false
    visitast(wrapper, function(node)
        local kind = node.kind
        if kind == 'VariableExpression' or kind == 'AssignmentVariable'
            or kind == 'FunctionDeclaration' then
            local scope = node.scope
            if not scope.isGlobal and not owned[scope] then
                if kind == 'AssignmentVariable'
                    or (kind == 'FunctionDeclaration' and #node.indices == 0) then
                    writes = true
                end
                seen[scope] = seen[scope] or {}
                if not seen[scope][node.id] then
                    variables[#variables + 1] = scope:getVariableName(node.id)
                    seen[scope][node.id] = true
                end
            end
        end
    end)
    -- A value prefix preserves shared tables/functions, but cannot forward writes
    -- to an outer lexical local. Use the ordinary compiler in that uncommon case.
    return variables, writes
end

return function(ast)
    local runtime = ast.vmRuntime
    local variables, writes = externalVariables(ast, runtime)
    if writes then return nil end
    local parser = Parser:new({LuaVersion = Enums.LuaVersion.Lua51, AllowInternalIdentifiers = true})
    local unparser = Unparser:new({LuaVersion = Enums.LuaVersion.Lua51})
    local runtimeSource = unparser:unparseExpression(runtime, 0)
    local prefix = ''
    local arguments = '...'
    if #variables > 0 then
        prefix = 'local ' .. table.concat(variables, ',') .. '=...;'
        arguments = 'select(' .. (#variables + 1) .. ',...)'
    end
    local standalone = parser:parse(prefix .. 'return (' .. runtimeSource .. ')(' .. arguments .. ')')
    local flattened = unparser:unparse(CffCompiler:new():compile(standalone))
    local forwarded = #variables > 0 and table.concat(variables, ',') .. ',...' or '...'
    local replacementSource = 'return function(...) return (function(...) '
        .. flattened .. ' end)(' .. forwarded .. ') end'
    local replacement = parser:parse(replacementSource).body.statements[1].args[1]
    visitast(ast, function(node)
        if node == runtime then return replacement, true end
    end)
    -- Reparsing resolves injected free-variable names against their original outer
    -- scopes, including helpers installed between Vmify and Cff by EncryptStrings.
    return parser:parse(unparser:unparse(ast))
end

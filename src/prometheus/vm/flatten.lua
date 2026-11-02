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
        if kind == 'VariableExpression' or kind == 'GlobalVariableExpression'
            or kind == 'AssignmentVariable' or kind == 'AssignmentGlobalVariable'
            or kind == 'FunctionDeclaration' then
            local scope = node.scope
            if not scope.isGlobal and not owned[scope] then
                if kind == 'AssignmentVariable' or kind == 'AssignmentGlobalVariable'
                    or (kind == 'FunctionDeclaration' and #node.indices == 0) then
                    writes = true
                end
                seen[scope] = seen[scope] or {}
                if not seen[scope][node.id] then
                    variables[#variables + 1] = node.symbol
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
    -- Serialize captures through fresh marker names, then reconnect the parsed
    -- forwarding references to their original symbols. Textual name resolution
    -- would silently rebind them when surrounding locals are renamed.
    local used, markers, captures = {}, {}, {}
    visitast(ast, function(node)
        if node.scope then
            for _, name in pairs(node.scope.variables) do used[name] = true end
        end
        if node.name then used[node.name] = true end
    end)
    local markerNames = {}
    for i, symbol in ipairs(variables) do
        local name = '__prometheus_capture_' .. i
        while used[name] do name = name .. '_' end
        used[name], markers[symbol], captures[name], markerNames[i] = true, name, symbol, name
    end
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})},
        Scope:new(ast.globalScope)), ast.globalScope)
    visitast(wrapper, nil, function(node)
        local name = markers[node.symbol]
        if name then
            if node.kind == 'VariableExpression' then return Ast.GlobalVariableExpression(name) end
            if node.kind == 'FunctionDeclaration' then
                node.symbol, node.name = nil, name
                node.scope, node.id = ast.globalScope:resolve(name)
                node.baseScope, node.baseId = node.scope, node.id
            end
        end
    end)
    local runtimeSource = unparser:unparseExpression(runtime, 0)
    local prefix = ''
    local arguments = '...'
    if #variables > 0 then
        prefix = 'local ' .. table.concat(markerNames, ',') .. '=...;'
        arguments = 'select(' .. (#variables + 1) .. ',...)'
    end
    local standalone = parser:parse(prefix .. 'return (' .. runtimeSource .. ')(' .. arguments .. ')')
    local flattened = unparser:unparse(CffCompiler:new():compile(standalone))
    local forwarded = #variables > 0 and table.concat(markerNames, ',') .. ',...' or '...'
    local replacementSource = 'return function(...) return (function(...) '
        .. flattened .. ' end)(' .. forwarded .. ') end'
    local replacement = parser:parse(replacementSource).body.statements[1].args[1]
    local replacementAst = Ast.TopNode(Ast.Block({Ast.ReturnStatement({replacement})},
        Scope:new(ast.globalScope)), ast.globalScope)
    visitast(replacementAst, nil, function(node)
        if node.kind == 'GlobalVariableExpression' and captures[node.name] then
            return Ast.VariableExpression(captures[node.name])
        end
    end)
    visitast(ast, function(node)
        if node == runtime then return replacement, true end
    end)
    ast.vmRuntime = replacement
    require('prometheus.bindinganalysis')(ast)
    return ast
end

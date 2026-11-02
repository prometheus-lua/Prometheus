-- Flatten a generated interpreter without virtualizing its large data initializer.
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local CffCompiler = require('prometheus.cff.compiler')
local analyzeBindings = require('prometheus.bindinganalysis')

local function externalVariables(ast, runtime)
    local owned, variables, seen = {}, {}, {}
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})}))
    visitast(wrapper, function(node)
        if node.kind == 'Block' and node.scope then owned[node.scope] = true end
    end)
    local writes = false
    visitast(wrapper, function(node)
        local kind = node.kind
        if kind == 'VariableExpression' or kind == 'GlobalVariableExpression'
            or kind == 'AssignmentVariable' or kind == 'AssignmentGlobalVariable'
            or kind == 'FunctionDeclaration' then
            local scope = node.scope
            if scope and not scope.isGlobal and not owned[scope] then
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
    analyzeBindings(ast)
    local runtime = ast.vmRuntime
    local variables, writes = externalVariables(ast, runtime)
    if writes then return nil end
    -- Give standalone captures fresh parameter bindings. The forwarding reads
    -- below still point to the actual outer symbols, without textual rebinding.
    local parameters, replacements = {}, {}
    local forwarded = {}
    for i, symbol in ipairs(variables) do
        local parameter = Ast.LocalSymbol('runtime_capture_' .. i)
        parameters[i], replacements[symbol] = parameter, parameter
        forwarded[i] = Ast.VariableExpression(symbol)
    end
    forwarded[#forwarded + 1] = Ast.VarargExpression()
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})}))
    visitast(wrapper, nil, function(node)
        local parameter = replacements[node.symbol]
        if parameter then
            if node.kind == 'VariableExpression' then return Ast.VariableExpression(parameter) end
            if node.kind == 'FunctionDeclaration' then node.symbol = parameter end
        end
    end)
    local statements, arguments = {}, {Ast.VarargExpression()}
    if #parameters > 0 then
        statements[1] = Ast.LocalVariableDeclaration(parameters, {Ast.VarargExpression()})
        arguments = {Ast.FunctionCallExpression(Ast.GlobalVariableExpression('select'), {
            Ast.NumberExpression(#parameters + 1), Ast.VarargExpression(),
        })}
    end
    statements[#statements + 1] = Ast.ReturnStatement({Ast.FunctionCallExpression(runtime, arguments)})
    local standalone = Ast.TopNode(Ast.Block(statements))
    local flattened = CffCompiler:new():compile(standalone)
    local replacement = Ast.FunctionLiteralExpression({Ast.VarargExpression()}, Ast.Block({
        Ast.ReturnStatement({Ast.FunctionCallExpression(
            Ast.FunctionLiteralExpression({Ast.VarargExpression()}, flattened.body), forwarded)}),
    }))
    visitast(ast, function(node)
        if node == runtime then return replacement, true end
    end)
    ast.vmRuntime = replacement
    analyzeBindings(ast)
    return ast
end

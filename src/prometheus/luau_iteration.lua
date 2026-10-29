-- Keep iterator initialization native so protected __iter metatables work without
-- reflection. The callback remains in the caller's coroutine and shares captures.
local Ast = require('prometheus.ast')
local Scope = require('prometheus.scope')
local visitast = require('prometheus.visitast')
local K = Ast.AstKind

return function(ast, Parser)
    local function parsedFunction(source, parent)
        local parsed = Parser:new({LuaVersion = 'LuaU', AllowInternalIdentifiers = true}):parse('return ' .. source)
        local result = parsed.body.statements[1].args[1]
        result.body.scope:setParent(parent)
        return result
    end
    local function global(scope, name)
        local owner, id = scope:resolveGlobal(name)
        return Ast.VariableExpression(owner, id)
    end
    local function reference(scope, owner, id)
        if scope ~= owner then scope:addReferenceToHigherScope(owner, id) end
        return Ast.VariableExpression(owner, id)
    end
    local function pack(scope, expressions)
        local fn = parsedFunction('function(...) return {n=select("#",...),...} end', scope)
        return Ast.FunctionCallExpression(fn, expressions)
    end
    local function unpackValues(scope, owner, id)
        return Ast.FunctionCallExpression(global(scope, 'unpack'), {
            reference(scope, owner, id), Ast.NumberExpression(1),
            Ast.IndexExpression(reference(scope, owner, id), Ast.StringExpression('n')),
        })
    end

    visitast(ast, nil, function(node)
        if node.kind ~= K.ForInStatement then return nil end
        local scope = Scope:new(node.parentScope)
        local iterator, state, control = scope:addVariable(), scope:addVariable(), scope:addVariable()
        local action, values = scope:addVariable(), scope:addVariable()
        local savedArgs
        node.body.scope:setParent(scope)
        local wrapper = Ast.TopNode(node.body, ast.globalScope)
        visitast(wrapper, function(child, data)
            if data.functionData.depth ~= 0 then return nil end
            if child.kind == K.VarargExpression then
                savedArgs = savedArgs or scope:addVariable()
                local result = unpackValues(data.scope, scope, savedArgs)
                result.isParenthesizedExpression = child.isParenthesizedExpression
                return result, true
            elseif child.kind == K.BreakStatement and child.loop == node then
                return Ast.ReturnStatement{Ast.NumberExpression(1)}, true
            elseif child.kind == K.ContinueStatement and child.loop == node then
                return Ast.ReturnStatement{}, true
            end
        end, function(child, data)
            if data.functionData.depth == 0 and child.kind == K.ReturnStatement and not child.iterationControl then
                local result = Ast.ReturnStatement{Ast.NumberExpression(2), pack(data.scope, child.args)}
                result.iterationControl = true
                return result
            end
        end)
        -- Return nodes introduced for break/continue were skipped by previsit.
        local args, names = {}, {}
        for index, id in ipairs(node.ids) do
            args[index] = Ast.VariableExpression(node.scope, id)
            names[index] = 'v' .. index
        end
        local callback = Ast.FunctionLiteralExpression(args, node.body)
        local parameters = table.concat(names, ',')
        local helper = parsedFunction('function(callback,iterator,state,control) for ' .. parameters
            .. ' in iterator,state,control do local action,values=callback(' .. parameters
            .. ') if action then return action,values end end end', scope)
        helper.isNativeLuau = true
        local statements = {}
        if savedArgs then
            statements[#statements + 1] = Ast.LocalVariableDeclaration(scope, {savedArgs}, {pack(scope, {Ast.VarargExpression()})})
        end
        statements[#statements + 1] = Ast.LocalVariableDeclaration(scope, {iterator, state, control}, node.expressions)
        statements[#statements + 1] = Ast.LocalVariableDeclaration(scope, {action, values}, {
            Ast.FunctionCallExpression(helper, {callback, Ast.VariableExpression(scope, iterator),
                Ast.VariableExpression(scope, state), Ast.VariableExpression(scope, control)})})
        local returnScope = Scope:new(scope)
        statements[#statements + 1] = Ast.IfStatement(Ast.EqualsExpression(Ast.VariableExpression(scope, action), Ast.NumberExpression(2)),
            Ast.Block({Ast.ReturnStatement{unpackValues(returnScope, scope, values)}}, returnScope), {})
        return Ast.DoStatement(Ast.Block(statements, scope))
    end)
    return ast
end

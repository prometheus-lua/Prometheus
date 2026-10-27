-- Cache interpreter literals at startup so protected decoders stay off its hot path.
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local Kind = Ast.AstKind

return function(ast)
    local runtime, scope = ast.vmRuntime, ast.body.scope
    if not runtime then return end
    local cacheScope = runtime.body.scope
    local data, cache
    local entries, ids, variables, values = {}, {}, {}, {}
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})}, scope), ast.globalScope)
    visitast(wrapper, nil, function(node, context)
        if node.kind == Kind.StringExpression then
            if not data then data, cache = scope:addVariable(), cacheScope:addVariable() end
            local id = ids[node.value]
            if not id then
                id = #entries + 1
                ids[node.value] = id
                entries[id] = Ast.TableEntry(Ast.StringExpression(node.value))
                variables[id] = cacheScope:addVariable()
                values[id] = Ast.IndexExpression(Ast.VariableExpression(cacheScope, cache),
                    Ast.NumberExpression(id))
                cacheScope:addReferenceToHigherScope(cacheScope, cache)
            end
            context.scope:addReferenceToHigherScope(cacheScope, variables[id])
            return Ast.VariableExpression(cacheScope, variables[id])
        end
    end)
    if not data then return end
    cacheScope:addReferenceToHigherScope(scope, data)
    table.insert(runtime.body.statements, 1,
        Ast.LocalVariableDeclaration(cacheScope, {cache}, {Ast.VariableExpression(scope, data)}))
    table.insert(runtime.body.statements, 2,
        Ast.LocalVariableDeclaration(cacheScope, variables, values))
    table.insert(ast.body.statements, 1,
        Ast.LocalVariableDeclaration(scope, {data}, {Ast.TableConstructorExpression(entries)}))
end

-- Share repeated literals after Cff has introduced its own helper strings.
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local shuffle = require('prometheus.util').shuffle
local Kind = Ast.AstKind

return function(ast)
    local counts, strings = {}, {}
    visitast(ast, function(node)
        if node.kind == Kind.StringExpression then
            local value = node.value
            counts[value] = (counts[value] or 0) + 1
            if counts[value] == 2 then strings[#strings + 1] = value end
        end
    end)
    if #strings == 0 then return ast end

    shuffle(strings)
    local scope = ast.body.scope
    local pool = scope:addVariable()
    local indices, entries = {}, {}
    for i, value in ipairs(strings) do
        indices[value] = i
        entries[i] = Ast.TableEntry(Ast.StringExpression(value))
    end
    -- Track blocks explicitly: strings after a nested function literal still
    -- belong to the enclosing block, regardless of the visitor's last scope.
    local scopes = {}
    visitast(ast, function(node)
        if node.kind == Kind.Block then scopes[#scopes + 1] = node.scope end
    end, function(node)
        if node.kind == Kind.Block then
            scopes[#scopes] = nil
        elseif node.kind == Kind.StringExpression then
            local index = indices[node.value]
            if index then
                scopes[#scopes]:addReferenceToHigherScope(scope, pool)
                return Ast.IndexExpression(Ast.VariableExpression(scope, pool), Ast.NumberExpression(index))
            end
        end
    end)
    -- Insert only after replacement so each pooled value remains embedded once.
    table.insert(ast.body.statements, 1,
        Ast.LocalVariableDeclaration(scope, {pool}, {Ast.TableConstructorExpression(entries)}))
    return ast
end

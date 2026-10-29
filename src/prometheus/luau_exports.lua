-- Lower value exports to a module table while retaining live mutable bindings.
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local K = Ast.AstKind

return function(ast, bindings)
    if #bindings == 0 then return ast end
    local scope, lookup = ast.body.scope, {}
    local tableId = scope:addVariable()
    for _, binding in ipairs(bindings) do
        lookup[binding.scope] = lookup[binding.scope] or {}
        lookup[binding.scope][binding.id] = binding.name
    end
    local function access(owner, id, useScope, assignment)
        local name = lookup[owner] and lookup[owner][id]
        if not name then return nil end
        if useScope ~= scope then useScope:addReferenceToHigherScope(scope, tableId) end
        local base = Ast.VariableExpression(scope, tableId)
        return (assignment and Ast.AssignmentIndexing or Ast.IndexExpression)(base, Ast.StringExpression(name))
    end
    visitast(ast, function(node, data)
        if node.kind == K.VariableExpression or node.kind == K.AssignmentVariable then
            return access(node.scope, node.id, data.scope, node.kind == K.AssignmentVariable)
        elseif node.kind == K.LocalVariableDeclaration and node.isExported then
            local targets = {}
            for _, id in ipairs(node.ids) do targets[#targets + 1] = access(node.scope, id, data.scope, true) end
            local values = node.expressions
            if #values == 0 then values = {Ast.NilExpression()} end
            return Ast.AssignmentStatement(targets, values)
        elseif (node.kind == K.LocalFunctionDeclaration and node.isExported) or node.kind == K.FunctionDeclaration then
            local target = access(node.scope, node.id, data.scope, true)
            if not target then return nil end
            for _, name in ipairs(node.indices or {}) do
                target.kind = K.IndexExpression
                target = Ast.AssignmentIndexing(target, Ast.StringExpression(name))
            end
            local value = Ast.FunctionLiteralExpression(node.args, node.body)
            value.attributes = node.attributes
            return Ast.AssignmentStatement({target}, {value})
        end
    end)
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, {tableId}, {Ast.TableConstructorExpression({})}))
    local tableScope, libraryId = scope:resolveGlobal('table')
    local freeze = Ast.IndexExpression(Ast.VariableExpression(tableScope, libraryId), Ast.StringExpression('freeze'))
    ast.body.statements[#ast.body.statements + 1] = Ast.ReturnStatement{
        Ast.FunctionCallExpression(freeze, {Ast.VariableExpression(scope, tableId)})}
    return ast
end

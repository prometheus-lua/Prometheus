-- Identify each lexical scope's function and locals shared with nested closures.
local visitast = require('prometheus.visitast')

return function(ast)
    local analysis = {owners = {}, captured = {}}
    visitast(ast, function(node, data)
        if node.kind == 'Block' then
            analysis.owners[node.scope] = data.functionData.scope
        end
    end)
    visitast(ast, function(node, data)
        local kind = node.kind
        if kind == 'VariableExpression' or kind == 'AssignmentVariable'
            or kind == 'FunctionDeclaration' then
            local scope = node.scope
            if not scope.isGlobal and analysis.owners[scope] ~= data.functionData.scope then
                analysis.captured[scope] = analysis.captured[scope] or {}
                analysis.captured[scope][node.id] = true
            end
        end
    end)
    return analysis
end

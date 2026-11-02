-- Cache interpreter literals at startup so protected decoders stay off its hot path.
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local Kind = Ast.AstKind

return function(ast)
    local runtime = ast.vmRuntime
    if not runtime then return end
    local data, cache
    local entries, ids, variables, values = {}, {}, {}, {}
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({runtime})}))
    visitast(wrapper, nil, function(node, context)
        if node.kind == Kind.StringExpression then
            if not data then
                data, cache = Ast.LocalSymbol('_vm_string_data'), Ast.LocalSymbol('_vm_string_cache')
            end
            local id = ids[node.value]
            if not id then
                id = #entries + 1
                ids[node.value] = id
                entries[id] = Ast.TableEntry(Ast.StringExpression(node.value))
                variables[id] = Ast.LocalSymbol('_vm_string_value_' .. id)
                values[id] = Ast.IndexExpression(Ast.VariableExpression(cache),
                    Ast.NumberExpression(id))
            end
            return Ast.VariableExpression(variables[id])
        end
    end)
    if not data then return end
    table.insert(runtime.body.statements, 1,
        Ast.LocalVariableDeclaration({cache}, {Ast.VariableExpression(data)}))
    table.insert(runtime.body.statements, 2,
        Ast.LocalVariableDeclaration(variables, values))
    table.insert(ast.body.statements, 1,
        Ast.LocalVariableDeclaration({data}, {Ast.TableConstructorExpression(entries)}))
end

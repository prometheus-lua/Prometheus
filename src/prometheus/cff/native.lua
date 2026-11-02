-- Keep selected expressions native, bridging captures through Cff's shared cells.
local Ast = require('prometheus.ast')
local Kind = Ast.AstKind

local function walk(expression, previsit, postvisit)
    return require('prometheus.visitast')(Ast.TopNode(Ast.Block({
        Ast.ReturnStatement({expression}),
    })), previsit, postvisit)
end

local function captures(expression)
    local owned, variables, seen = {}, {}, {}
    walk(expression, function(node)
        if node.kind == Kind.Block and node.scope then
            owned[node.scope] = true
        end
    end)
    walk(expression, function(node)
        local isGlobal = node.kind == Kind.GlobalVariableExpression
            or node.kind == Kind.AssignmentGlobalVariable
            or (node.kind == Kind.FunctionDeclaration and not node.symbol)
        if (node.kind == Kind.VariableExpression or node.kind == Kind.AssignmentVariable
            or node.kind == Kind.FunctionDeclaration) and not isGlobal and node.symbol
            and not owned[node.symbol.scope] then
            local scope, id = node.symbol.scope, node.symbol.id
            seen[scope] = seen[scope] or {}
            if not seen[scope][id] then
                variables[#variables + 1] = {scope = scope, id = id, symbol = node.symbol}
                seen[scope][id] = #variables
            end
        end
    end)
    return variables, seen, owned
end

return function(Compiler)
    function Compiler:prepareNativeExpressions()
        self.nativeResults = {}
        for expression in pairs(self.nativeExpressions) do
            local variables = captures(expression)
            for _, variable in ipairs(variables) do
                self:makeUpvalue(variable.scope, variable.id)
            end
        end
    end

    function Compiler:compileNativeExpression(expression, funcDepth, numReturns)
        local variables, lookup, owned = captures(expression)
        local entries, reads = {}, {}
        for _, variable in ipairs(variables) do
            local depth = self.scopeFunctionDepths[variable.scope]
            local id
            if depth == funcDepth then
                local register = self:getVarRegister(variable.scope, variable.id, funcDepth)
                id = self:register(register)
                reads[#reads + 1] = register
            else
                local index = self:getUpvalueId(variable.scope, variable.id)
                id = Ast.IndexExpression(Ast.VariableExpression(self.currentUpvaluesVar), Ast.NumberExpression(index))
            end
            entries[#entries + 1] = Ast.TableEntry(id)
        end

        -- The bridge parameters are bindings, so native locals can keep their
        -- symbols even when preferred names collide with each other or helpers.
        local proxySymbol = Ast.LocalSymbol('native_proxy')
        local envSymbol = Ast.LocalSymbol('native_env')
        local valuesSymbol = Ast.LocalSymbol('native_values')
        local resultSymbol = Ast.LocalSymbol('native_result')
        local function access(node, assignment)
            local base, index
            if node.kind == Kind.GlobalVariableExpression or node.kind == Kind.AssignmentGlobalVariable
                or (node.kind == Kind.FunctionDeclaration and not node.symbol) then
                local name = node.name
                if name == '_ENV' and not assignment then return Ast.VariableExpression(envSymbol) end
                base, index = Ast.VariableExpression(envSymbol), Ast.StringExpression(name)
            else
                local symbol = node.symbol
                local scope, id = symbol and symbol.scope, symbol and symbol.id
                local slot = scope and lookup[scope] and lookup[scope][id]
                if not slot then return end
                base = Ast.VariableExpression(valuesSymbol)
                index = Ast.IndexExpression(Ast.VariableExpression(proxySymbol), Ast.NumberExpression(slot))
            end
            if assignment then return Ast.AssignmentIndexing(base, index) end
            return Ast.IndexExpression(base, index)
        end
        walk(expression, nil, function(node)
            if node.kind == Kind.VariableExpression or node.kind == Kind.GlobalVariableExpression then return access(node, false) end
            if node.kind == Kind.AssignmentVariable or node.kind == Kind.AssignmentGlobalVariable then return access(node, true) end
            if node.kind == Kind.FunctionDeclaration and not owned[node.scope] then
                local target = access(node, false)
                if target then
                    for _, key in ipairs(node.indices) do
                        target = Ast.IndexExpression(target, Ast.StringExpression(key))
                    end
                    return Ast.AssignmentStatement({Ast.AssignmentIndexing(target.base, target.index)},
                        {Ast.FunctionLiteralExpression(node.args, node.body)})
                end
            end
        end)

        local statements = {Ast.LocalVariableDeclaration({resultSymbol}, {expression})}
        if expression.kind == Kind.FunctionLiteralExpression then
            statements[#statements + 1] = Ast.IfStatement(
                Ast.VariableExpression(self.setfenvVar), Ast.Block({
                    Ast.FunctionCallStatement(Ast.VariableExpression(self.setfenvVar), {
                        Ast.VariableExpression(resultSymbol), Ast.VariableExpression(envSymbol),
                    }),
                }), {})
        end
        statements[#statements + 1] = Ast.ReturnStatement({Ast.VariableExpression(resultSymbol)})
        local factory = Ast.FunctionLiteralExpression({proxySymbol, envSymbol, valuesSymbol}, Ast.Block(statements))
        self.nativeResults[expression] = expression
        local proxy = Ast.NilExpression()
        if #entries > 0 then
            proxy = Ast.FunctionCallExpression(Ast.VariableExpression(self.upvaluesProxyFunctionVar), {Ast.TableConstructorExpression(entries)})
        end
        local value = Ast.FunctionCallExpression(factory, {proxy, self:env(),
            Ast.VariableExpression(self.upvaluesTable)})
        local result = self:allocRegister(false)
        self:addStatement(self:setRegister(result, value), {result}, reads, true)
        local registers = {result}
        for i = 2, numReturns do
            registers[i] = self:allocRegister(false)
            self:addStatement(self:setRegister(registers[i], Ast.NilExpression()),
                {registers[i]}, {}, false)
        end
        return registers
    end
end

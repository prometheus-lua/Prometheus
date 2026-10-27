-- Keep selected expressions native, bridging captures through Cff's shared cells.
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local Kind = Ast.AstKind

local function walk(expression, ast, previsit, postvisit)
    return require('prometheus.visitast')(Ast.TopNode(Ast.Block({
        Ast.ReturnStatement({expression}),
    }, ast.body.scope), ast.globalScope), previsit, postvisit)
end

local function captures(expression, ast)
    local owned, variables, seen = {}, {}, {}
    walk(expression, ast, function(node)
        if node.kind == Kind.Block and node.scope ~= ast.body.scope then
            owned[node.scope] = true
        end
    end)
    walk(expression, ast, function(node)
        if (node.kind == Kind.VariableExpression or node.kind == Kind.AssignmentVariable
            or node.kind == Kind.FunctionDeclaration) and not node.scope.isGlobal
            and not owned[node.scope] then
            seen[node.scope] = seen[node.scope] or {}
            if not seen[node.scope][node.id] then
                variables[#variables + 1] = {scope = node.scope, id = node.id}
                seen[node.scope][node.id] = #variables
            end
        end
    end)
    return variables, seen, owned
end

return function(Compiler)
    function Compiler:prepareNativeExpressions(ast)
        self.nativeAst, self.nativeResults = ast, {}
        for expression in pairs(self.nativeExpressions) do
            local variables = captures(expression, ast)
            for _, variable in ipairs(variables) do
                self:makeUpvalue(variable.scope, variable.id)
            end
        end
    end

    function Compiler:compileNativeExpression(expression, funcDepth, numReturns)
        local ast, scope = self.nativeAst, self.activeBlock.scope
        local variables, lookup, owned = captures(expression, ast)
        local entries, reads = {}, {}
        for _, variable in ipairs(variables) do
            local depth = self.scopeFunctionDepths[variable.scope]
            local id
            if depth == funcDepth then
                local register = self:getVarRegister(variable.scope, variable.id, funcDepth)
                id = self:register(scope, register)
                reads[#reads + 1] = register
            else
                local index = self:getUpvalueId(variable.scope, variable.id)
                scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar)
                id = Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope,
                    self.currentUpvaluesVar), Ast.NumberExpression(index))
            end
            entries[#entries + 1] = Ast.TableEntry(id)
        end

        -- Fresh marker names avoid shadowing any names inside the native expression.
        local used = {}
        walk(expression, ast, function(node)
            if node.scope then
                for _, name in pairs(node.scope.variables) do used[name] = true end
            end
        end)
        local names = {}
        for _, label in ipairs({'proxy', 'env', 'values', 'setenv', 'result'}) do
            local name = '__prometheus_native_' .. label
            while used[name] do name = name .. '_' end
            used[name], names[label] = true, name
        end
        local function marker(label)
            local _, id = ast.globalScope:resolve(names[label])
            return Ast.VariableExpression(ast.globalScope, id)
        end
        local function access(node, assignment)
            local base, index
            if node.scope.isGlobal then
                local name = node.scope:getVariableName(node.id)
                if name == '_ENV' and not assignment then return marker('env') end
                base, index = marker('env'), Ast.StringExpression(name)
            else
                local slot = lookup[node.scope] and lookup[node.scope][node.id]
                if not slot then return end
                base = marker('values')
                index = Ast.IndexExpression(marker('proxy'), Ast.NumberExpression(slot))
            end
            if assignment then return Ast.AssignmentIndexing(base, index) end
            return Ast.IndexExpression(base, index)
        end
        walk(expression, ast, nil, function(node)
            if node.kind == Kind.VariableExpression then return access(node, false) end
            if node.kind == Kind.AssignmentVariable then return access(node, true) end
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

        local source = Unparser:new({LuaVersion = 'Lua51'}):unparseExpression(expression, 0)
        local finish = ''
        if expression.kind == Kind.FunctionLiteralExpression then
            finish = 'if ' .. names.setenv .. ' then ' .. names.setenv .. '(' .. names.result
                .. ',' .. names.env .. ') end;'
        end
        local parsed = Parser:new({LuaVersion = 'Lua51', AllowInternalIdentifiers = true}):parse('return function('
            .. names.proxy .. ',' .. names.env .. ',' .. names.values .. ') local '
            .. names.result .. '=' .. source .. ';' .. finish .. 'return ' .. names.result .. ' end')
        local factory = parsed.body.statements[1].args[1]
        self.nativeResults[expression] = factory.body.statements[1].expressions[1]
        factory.body.scope:setParent(scope)
        require('prometheus.visitast')(parsed, nil, function(node, data)
            if node.kind == Kind.VariableExpression and node.scope.isGlobal then
                assert(node.scope:getVariableName(node.id) == names.setenv, 'Unexpected native global')
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(self.scope, self.setfenvVar)
                return Ast.VariableExpression(self.scope, self.setfenvVar)
            end
        end)
        local proxy = Ast.NilExpression()
        if #entries > 0 then
            scope:addReferenceToHigherScope(self.scope, self.upvaluesProxyFunctionVar)
            proxy = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope,
                self.upvaluesProxyFunctionVar), {Ast.TableConstructorExpression(entries)})
        end
        scope:addReferenceToHigherScope(self.scope, self.upvaluesTable)
        local value = Ast.FunctionCallExpression(factory, {proxy, self:env(scope),
            Ast.VariableExpression(self.scope, self.upvaluesTable)})
        local result = self:allocRegister(false)
        self:addStatement(self:setRegister(scope, result, value), {result}, reads, true)
        local registers = {result}
        for i = 2, numReturns do
            registers[i] = self:allocRegister(false)
            self:addStatement(self:setRegister(scope, registers[i], Ast.NilExpression()),
                {registers[i]}, {}, false)
        end
        return registers
    end
end

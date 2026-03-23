-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- continue_statement.lua
--
-- This Script contains the statement handler for the ContinueStatement.

local Ast = require("prometheus.ast");

return function(self, statement, funcDepth)
    local scope = self.activeBlock.scope;
    local toFreeVars = {};
    local statScope;
    repeat
        statScope = statScope and statScope.parentScope or statement.scope;
        for id, _ in pairs(statScope.variables) do
            table.insert(toFreeVars, {
                scope = statScope,
                id = id;
            });
        end
    until statScope == statement.loop.body.scope;

    for _, var in ipairs(toFreeVars) do
        local varScope, id = var.scope, var.id;
        local varReg = self:getVarRegister(varScope, id, nil, nil);
        if self:isUpvalue(varScope, id) then
            scope:addReferenceToHigherScope(self.scope, self.freeUpvalueFunc);
            self:addStatement(self:setRegister(scope, varReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.freeUpvalueFunc), {
                self:register(scope, varReg)
            })), {varReg}, {varReg}, false);
        else
            self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), {varReg}, {}, false);
        end
    end


    self:addStatement(self:setPos(scope, statement.loop.__start_block.id), {self.POS_REGISTER}, {}, false);
    self.activeBlock.advanceToNextBlock = false;
end;

-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- number.lua
--
-- This Script contains the expression handler for the NumberExpression.

local Ast = require("prometheus.ast");

return function(self, expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;
    local regs = {};
    for i = 1, numReturns do
        regs[i] = self:allocRegister();
        if i == 1 then
            if type(expression.value) == "number" and expression.value == 0 and 1 / expression.value < 0 then
                -- Keep negative zero out of native Lua 5.1 numeric constants.
                -- The register read makes this runtime negation distinct from a -0 literal.
                self:addStatement(self:setRegister(scope, regs[i], Ast.NumberExpression(0)), {regs[i]}, {}, false);
                self:addStatement(self:setRegister(scope, regs[i], Ast.NegateExpression(self:register(scope, regs[i]))), {regs[i]}, {regs[i]}, false);
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NumberExpression(expression.value)), {regs[i]}, {}, false);
            end
        else
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
        end
    end
    return regs;
end;


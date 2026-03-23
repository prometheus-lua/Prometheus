-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- string.lua
--
-- This Script contains the expression handler for the StringExpression.

local Ast = require("prometheus.ast");

return function(self, expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;
    local regs = {};
    for i = 1, numReturns, 1 do
        regs[i] = self:allocRegister();
        if i == 1 then
            self:addStatement(self:setRegister(scope, regs[i], Ast.StringExpression(expression.value)), {regs[i]}, {}, false);
        else
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
        end
    end
    return regs;
end;


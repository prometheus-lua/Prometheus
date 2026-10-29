-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- binary.lua
--
-- This Script contains the expression handler for the Binary operations (Add, Sub, Mul, Div, etc.).

local Ast = require("prometheus.ast");

return function(self, expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;
    local regs = {};
    for i = 1, numReturns do
        regs[i] = self:allocRegister();
        if i == 1 then
            local lhsReg, rhsReg;
            local lhs = expression.lhs;
            local deferRead = expression.kind == Ast.AstKind.FloorDivExpression
                and lhs.kind == Ast.AstKind.VariableExpression and not lhs.scope.isGlobal
                and self.scopeFunctionDepths[lhs.scope] == funcDepth;
            if not deferRead then lhsReg = self:compileExpression(lhs, funcDepth, 1)[1] end
            rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];
            if deferRead then lhsReg = self:compileExpression(lhs, funcDepth, 1)[1] end

            local binaryExpr = Ast[expression.kind](self:register(scope, lhsReg), self:register(scope, rhsReg));
            self:addStatement(self:setRegister(scope, regs[i], binaryExpr), {regs[i]}, {lhsReg, rhsReg}, true);
            self:freeRegister(rhsReg, false);
            self:freeRegister(lhsReg, false);
        else
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
        end
    end
    return regs;
end;

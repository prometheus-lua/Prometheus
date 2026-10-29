-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- index.lua
--
-- This Script contains the expression handler for the IndexExpression.

local Ast = require("prometheus.ast");

return function(self, expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;
    local regs = {};
    for i = 1, numReturns do
        regs[i] = self:allocRegister();
        if i == 1 then
            local baseReg;
            local base = expression.base;
            local deferRead = self.luaVersion == "LuaU" and base.kind == Ast.AstKind.VariableExpression
                and not base.scope.isGlobal and self.scopeFunctionDepths[base.scope] == funcDepth;
            if not deferRead then baseReg = self:compileExpression(base, funcDepth, 1)[1] end
            local indexReg = self:compileExpression(expression.index, funcDepth, 1)[1];
            if deferRead then baseReg = self:compileExpression(base, funcDepth, 1)[1] end
            self:addStatement(self:setRegister(scope, regs[i], Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, indexReg))), {regs[i]}, {baseReg, indexReg}, true);

            self:freeRegister(baseReg, false);
            self:freeRegister(indexReg, false);
        else
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
        end
    end
    return regs;
end;

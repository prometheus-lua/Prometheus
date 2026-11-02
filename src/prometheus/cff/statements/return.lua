-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- return.lua
--
-- This Script contains the statement handler for the ReturnStatement.

local Ast = require("prometheus.ast");
local AstKind = Ast.AstKind;

return function(self, statement, funcDepth)
    local entries = {};
    local regs = {};

    for i, expr in ipairs(statement.args) do
        if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
            local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
            table.insert(entries, Ast.FunctionCallExpression(
                self:unpack(),
                {self:register(reg)}));
            table.insert(regs, reg);
        else
            local reg = self:compileExpression(expr, funcDepth, 1)[1];
            table.insert(entries, self:register(reg));
            table.insert(regs, reg);
        end
    end

    self:addStatement(self:setReturn(self:pack(entries)), {self.RETURN_REGISTER}, regs, false);
    for _, reg in ipairs(regs) do
        self:freeRegister(reg, false);
    end
    self:addStatement(self:setPos(nil), {self.POS_REGISTER}, {}, false);
    self.activeBlock.advanceToNextBlock = false;
end;

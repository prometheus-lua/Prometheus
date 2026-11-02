-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- pass_self_function_call.lua
--
-- This Script contains the expression handler for the PassSelfFunctionCallExpression.

local Ast = require("prometheus.ast");
local AstKind = Ast.AstKind;

return function(self, expression, funcDepth, numReturns)
    local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1];
    local retRegs = {};
    local returnAll = numReturns == self.RETURN_ALL;
    if returnAll then
        retRegs[1] = self:allocRegister(false);
    else
        for i = 1, numReturns do
            retRegs[i] = self:allocRegister(false);
        end
    end

    local args = { self:register(baseReg) };
    local regs = { baseReg };

    for i, expr in ipairs(expression.args) do
        if i == #expression.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression or expr.kind == AstKind.VarargExpression) then
            local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
            table.insert(args, Ast.FunctionCallExpression(
                self:unpack(),
                {self:register(reg)}));
            table.insert(regs, reg);
        else
            local reg = self:compileExpression(expr, funcDepth, 1)[1];
            table.insert(args, self:register(reg));
            table.insert(regs, reg);
        end
    end

    if returnAll or numReturns > 1 then
        local tmpReg = self:allocRegister(false);

        self:addStatement(self:setRegister(tmpReg, Ast.StringExpression(expression.passSelfFunctionName)), {tmpReg}, {}, false);
        self:addStatement(self:setRegister(tmpReg, Ast.IndexExpression(self:register(baseReg), self:register(tmpReg))), {tmpReg}, {baseReg, tmpReg}, true);

        if returnAll then
            self:addStatement(self:setRegister(retRegs[1], self:pack({self:functionCall(tmpReg, args)})), {retRegs[1]}, {tmpReg, unpack(regs)}, true);
        else
            self:addStatement(self:setRegister(tmpReg, Ast.TableConstructorExpression{Ast.TableEntry(self:functionCall(tmpReg, args))}), {tmpReg}, {tmpReg, unpack(regs)}, true);

            for i, reg in ipairs(retRegs) do
                self:addStatement(self:setRegister(reg, Ast.IndexExpression(self:register(tmpReg), Ast.NumberExpression(i))), {reg}, {tmpReg}, false);
            end
        end

        self:freeRegister(tmpReg, false);
    else
        local tmpReg = retRegs[1] or self:allocRegister(false);

        self:addStatement(self:setRegister(tmpReg, Ast.StringExpression(expression.passSelfFunctionName)), {tmpReg}, {}, false);
        self:addStatement(self:setRegister(tmpReg, Ast.IndexExpression(self:register(baseReg), self:register(tmpReg))), {tmpReg}, {baseReg, tmpReg}, true);
        self:addStatement(self:setRegister(retRegs[1], self:functionCall(tmpReg, args)), {retRegs[1]}, {baseReg, unpack(regs)}, true);
    end

    for i, reg in ipairs(regs) do
        self:freeRegister(reg, false);
    end

    return retRegs;
end;

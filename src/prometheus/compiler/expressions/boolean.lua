-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- boolean.lua
--
-- This Script contains the expression handler for the BooleanExpression.

local Ast = require("prometheus.ast");
local function createRandomASTCFlowExpression(resultBool)
    local expTB = {
        Ast.GreaterThanExpression,
        Ast.LessThanExpression,
        Ast.GreaterThanOrEqualsExpression,
        Ast.LessThanOrEqualsExpression,
        Ast.NotEqualsExpression
    }

    local expLookup = {
        [Ast.GreaterThanExpression] = ">";
        [Ast.LessThanExpression] = "<";
        [Ast.GreaterThanOrEqualsExpression] = ">=";
        [Ast.LessThanOrEqualsExpression] = "<=";
        [Ast.NotEqualsExpression] = "~=";
    }

    local leftInt, rightInt, boolResult, r3, randomExp
    repeat
        randomExp = expTB[math.random(1, #expTB)]
        leftInt = Ast.NumberExpression(math.random(1, 2^24))
        rightInt = Ast.NumberExpression(math.random(1, 2^24))
        r3 = "return " .. leftInt.value .. expLookup[randomExp] .. rightInt.value
        boolResult = (loadstring or load)(r3)()
    until boolResult == resultBool

    return randomExp(leftInt, rightInt, false)
end

return function(self, expression, _, numReturns)
    local scope = self.activeBlock.scope;
    local regs = {};
    for i = 1, numReturns do
        regs[i] = self:allocRegister();
        if i == 1 then
            self:addStatement(self:setRegister(scope, regs[i], createRandomASTCFlowExpression(expression.value)), {regs[i]}, {}, false);
        else
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
        end
    end
    return regs;
end;


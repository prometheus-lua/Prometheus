-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- compile_core.lua
-- This Script contains the core compilation functions: compileTopNode, compileFunction, compileBlock,
-- compileStatement, and compileExpression

local compileTop = require("prometheus.cff.compile_top");
local statementHandlers = require("prometheus.cff.statements");
local expressionHandlers = require("prometheus.cff.expressions");
local Ast = require("prometheus.ast");
local logger = require("logger");

return function(Compiler)
    compileTop(Compiler);

    function Compiler:compileStatement(statement, funcDepth)
        local handler = statementHandlers[statement.kind];
        if handler then
            handler(self, statement, funcDepth);
            return;
        end
        logger:error(string.format("%s is not a compileable statement!", statement.kind));
    end

    function Compiler:compileExpression(expression, funcDepth, numReturns)
        if self.nativeExpressions and self.nativeExpressions[expression] then
            return self:compileNativeExpression(expression, funcDepth, numReturns);
        end
        local handler = expressionHandlers[expression.kind];
        if handler then
            local kind = expression.kind;
            if expression.isParenthesizedExpression and
                (kind == Ast.AstKind.FunctionCallExpression or kind == Ast.AstKind.PassSelfFunctionCallExpression or kind == Ast.AstKind.VarargExpression) and
                (numReturns == self.RETURN_ALL or numReturns > 1) then
                -- Parentheses collapse multiple values to one, even when it is nil.
                local regs = handler(self, expression, funcDepth, 1);
                local scope = self.activeBlock.scope;
                if numReturns == self.RETURN_ALL then
                    local packed = self:allocRegister(false);
                    self:addStatement(self:setRegister(scope, packed, self:pack(scope, {self:register(scope, regs[1])})), {packed}, {regs[1]}, false);
                    self:freeRegister(regs[1], false);
                    return {packed};
                end
                for i = 2, numReturns do
                    regs[i] = self:allocRegister(false);
                    self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {}, false);
                end
                return regs;
            end
            return handler(self, expression, funcDepth, numReturns);
        end
        logger:error(string.format("%s is not an compliable expression!", expression.kind));
    end
end

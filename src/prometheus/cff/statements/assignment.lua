-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- assignment.lua
--
-- This Script contains the statement handler for the AssignmentStatement.

local Ast = require("prometheus.ast");
local AstKind = Ast.AstKind;

local function isSideEffectFreeLiteral(expression)
    local kind = expression.kind;
    return kind == AstKind.NilExpression or kind == AstKind.BooleanExpression or
        kind == AstKind.NumberExpression or kind == AstKind.StringExpression;
end

return function(self, statement, funcDepth)
    local exprregs = {};
    local assignmentIndexingRegs = {};
    local function captureTarget(expression)
        local reg = self:compileExpression(expression, funcDepth, 1)[1];
        if self:isVarRegister(reg) then
            local snapshot = self:allocRegister(false);
            self:addStatement(self:copyRegisters({snapshot}, {reg}), {snapshot}, {reg}, false);
            reg = snapshot;
        end
        return reg;
    end

    for i, primaryExpr in ipairs(statement.lhs) do
        if(primaryExpr.kind == AstKind.AssignmentIndexing) then
            -- Later target/RHS evaluation and writes may replace these locals.
            assignmentIndexingRegs [i] = {
                base = captureTarget(primaryExpr.base),
                index = captureTarget(primaryExpr.index),
            };
        end
    end

    for i, expr in ipairs(statement.rhs) do
        if(i == #statement.rhs and #statement.lhs > #statement.rhs) then
            local regs = self:compileExpression(expr, funcDepth, #statement.lhs - #statement.rhs + 1);

            for i, reg in ipairs(regs) do
                if(self:isVarRegister(reg)) then
                    local ro = reg;
                    reg = self:allocRegister(false);
                    self:addStatement(self:copyRegisters({reg}, {ro}), {reg}, {ro}, false);
                end
                table.insert(exprregs, reg);
            end
        else
            if statement.lhs[i] then
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                if(self:isVarRegister(reg)) then
                    local ro = reg;
                    reg = self:allocRegister(false);
                    self:addStatement(self:copyRegisters({reg}, {ro}), {reg}, {ro}, false);
                end
                table.insert(exprregs, reg);
            else
                -- Lua evaluates every RHS expression, including values that
                -- have no corresponding assignment target.
                if not isSideEffectFreeLiteral(expr) then
                    local reg = self:compileExpression(expr, funcDepth, 1)[1];
                    self:freeRegister(reg, false);
                end
            end
        end
    end

    for i = #statement.lhs, 1, -1 do
        local primaryExpr = statement.lhs[i];
        if primaryExpr.kind == AstKind.AssignmentVariable or primaryExpr.kind == AstKind.AssignmentGlobalVariable then
            if primaryExpr.kind == AstKind.AssignmentGlobalVariable then
                local tmpReg = self:allocRegister(false);
                self:addStatement(self:setRegister(tmpReg, Ast.StringExpression(primaryExpr.name)), {tmpReg}, {}, false);
                self:addStatement(Ast.AssignmentStatement({Ast.AssignmentIndexing(self:env(), self:register(tmpReg))},
                 {self:register(exprregs[i])}), {}, {tmpReg, exprregs[i]}, true);
                self:freeRegister(tmpReg, false);
            else
                if self.scopeFunctionDepths[primaryExpr.scope] == funcDepth then
                    if self:isUpvalue(primaryExpr.scope, primaryExpr.id) then
                        local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth);
                        self:addStatement(self:setUpvalueMember(self:register(reg), self:register(exprregs[i])), {}, {reg, exprregs[i]}, true);
                    else
                        local reg = self:getVarRegister(primaryExpr.scope, primaryExpr.id, funcDepth, exprregs[i]);
                        if reg ~= exprregs[i] then
                            self:addStatement(self:setRegister(reg, self:register(exprregs[i])), {reg}, {exprregs[i]}, false);
                        end
                    end
                else
                    local upvalId = self:getUpvalueId(primaryExpr.scope, primaryExpr.id);
                    self:addStatement(self:setUpvalueMember(Ast.IndexExpression(Ast.VariableExpression(self.currentUpvaluesVar), Ast.NumberExpression(upvalId)), self:register(exprregs[i])), {}, {exprregs[i]}, true);
                end
            end
        elseif primaryExpr.kind == AstKind.AssignmentIndexing then
            local baseReg = assignmentIndexingRegs[i].base;
            local indexReg = assignmentIndexingRegs[i].index;
            self:addStatement(Ast.AssignmentStatement({
                Ast.AssignmentIndexing(self:register(baseReg), self:register(indexReg))
            }, {
                self:register(exprregs[i])
            }), {}, {exprregs[i], baseReg, indexReg}, true);
            self:freeRegister(baseReg, false);
            self:freeRegister(indexReg, false);
        else
            error(string.format("Invalid Assignment lhs: %s", statement.lhs));
        end
        self:freeRegister(exprregs[i], false);
    end
end;

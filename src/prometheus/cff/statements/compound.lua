-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- compound.lua
--
-- This Script contains the statement handler for the Compound statements (compound add, sub, mul, etc.)

local Ast = require("prometheus.ast");
local AstKind = Ast.AstKind;

local binaryConstructors = {
    [AstKind.CompoundAddStatement] = Ast.AddExpression,
    [AstKind.CompoundSubStatement] = Ast.SubExpression,
    [AstKind.CompoundMulStatement] = Ast.MulExpression,
    [AstKind.CompoundDivStatement] = Ast.DivExpression,
    [AstKind.CompoundFloorDivStatement] = Ast.FloorDivExpression,
    [AstKind.CompoundModStatement] = Ast.ModExpression,
    [AstKind.CompoundPowStatement] = Ast.PowExpression,
    [AstKind.CompoundConcatStatement] = Ast.StrCatExpression,
};

return function(self, statement, funcDepth)
    local scope = self.activeBlock.scope;
    local target = statement.lhs;
    local baseReg, indexReg, oldReg;
    local function isCurrentLocal(expression)
        return expression.kind == AstKind.VariableExpression and not expression.scope.isGlobal
            and self.scopeFunctionDepths[expression.scope] == funcDepth;
    end
    local function capture(expression)
        local reg = self:compileExpression(expression, funcDepth, 1)[1];
        if self:isVarRegister(reg) then
            local copy = self:allocRegister(false);
            self:addStatement(self:copyRegisters(scope, {copy}, {reg}), {copy}, {reg}, false);
            reg = copy;
        end
        return reg;
    end

    local indexed = target.kind == AstKind.AssignmentIndexing;
    local localTarget = not indexed and not target.scope.isGlobal
        and self.scopeFunctionDepths[target.scope] == funcDepth;
    local deferRead = localTarget and statement.kind ~= AstKind.CompoundConcatStatement;
    if indexed then
        -- Luau addresses direct locals through their current registers, including
        -- changes made while evaluating the key, RHS, or an operator metamethod.
        if not isCurrentLocal(target.base) then baseReg = capture(target.base) end
        indexReg = capture(target.index);
        if not baseReg then baseReg = capture(target.base) end
        oldReg = self:allocRegister(false);
        self:addStatement(self:setRegister(scope, oldReg, Ast.IndexExpression(self:register(scope, baseReg),
            self:register(scope, indexReg))), {oldReg}, {baseReg, indexReg}, true);
    elseif not deferRead then
        oldReg = capture(Ast.VariableExpression(target.scope, target.id));
    end
    -- Arithmetic reads current-function locals after RHS. Concatenation,
    -- globals, upvalues, and indexed values retain their earlier value.
    local valueReg = self:compileExpression(statement.rhs, funcDepth, 1)[1];
    if deferRead then oldReg = self:compileExpression(Ast.VariableExpression(target.scope, target.id), funcDepth, 1)[1] end
    local resultReg = self:allocRegister(false);
    local result = binaryConstructors[statement.kind](self:register(scope, oldReg), self:register(scope, valueReg));
    self:addStatement(self:setRegister(scope, resultReg, result), {resultReg}, {oldReg, valueReg}, true);

    if indexed then
        if isCurrentLocal(target.base) then
            self:freeRegister(baseReg, false);
            baseReg = capture(target.base);
        end
        if isCurrentLocal(target.index) then
            self:freeRegister(indexReg, false);
            indexReg = capture(target.index);
        end
        self:addStatement(Ast.AssignmentStatement({Ast.AssignmentIndexing(self:register(scope, baseReg),
            self:register(scope, indexReg))}, {self:register(scope, resultReg)}), {}, {baseReg, indexReg, resultReg}, true);
        self:freeRegister(baseReg, false);
        self:freeRegister(indexReg, false);
    elseif target.scope.isGlobal then
        self:addStatement(Ast.AssignmentStatement({Ast.AssignmentIndexing(self:env(scope),
            Ast.StringExpression(target.scope:getVariableName(target.id)))}, {self:register(scope, resultReg)}), {}, {resultReg}, true);
    elseif localTarget then
        local reg = self:getVarRegister(target.scope, target.id, funcDepth);
        if self:isUpvalue(target.scope, target.id) then
            self:addStatement(self:setUpvalueMember(scope, self:register(scope, reg), self:register(scope, resultReg)), {}, {reg, resultReg}, true);
        else
            self:addStatement(self:setRegister(scope, reg, self:register(scope, resultReg)), {reg}, {resultReg}, false);
        end
    else
        local upvalId = self:getUpvalueId(target.scope, target.id);
        scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
        self:addStatement(self:setUpvalueMember(scope, Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope,
            self.currentUpvaluesVar), Ast.NumberExpression(upvalId)), self:register(scope, resultReg)), {}, {resultReg}, true);
    end
    self:freeRegister(oldReg, false);
    self:freeRegister(valueReg, false);
    self:freeRegister(resultReg, false);
end;

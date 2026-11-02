-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- for_in_statement.lua
--
-- This Script contains the statement handler for the ForInStatement

local Ast = require("prometheus.ast");

return function(self, statement, funcDepth)
    local expressionsLength = #statement.expressions;
    local exprregs = {};
    for i, expr in ipairs(statement.expressions) do
        if(i == expressionsLength and expressionsLength < 3) then
            local regs = self:compileExpression(expr, funcDepth, 4 - expressionsLength);
            for i = 1, 4 - expressionsLength do
                table.insert(exprregs, regs[i]);
            end
        else
            if i <= 3 then
                table.insert(exprregs, self:compileExpression(expr, funcDepth, 1)[1])
            else
                self:freeRegister(self:compileExpression(expr, funcDepth, 1)[1], false);
            end
        end
    end

    for i, reg in ipairs(exprregs) do
        if reg and self.registers[reg] ~= self.VAR_REGISTER and reg ~= self.POS_REGISTER and reg ~= self.RETURN_REGISTER then
            self.registers[reg] = self.VAR_REGISTER;
        else
            exprregs[i] = self:allocRegister(true);
            self:addStatement(self:copyRegisters({exprregs[i]}, {reg}), {exprregs[i]}, {reg}, false);
        end
    end

    local checkBlock = self:createBlock();
    local bodyBlock = self:createBlock();
    local finalBlock = self:createBlock();

    statement.__start_block = checkBlock;
    statement.__final_block = finalBlock;

    self:addStatement(self:setPos(checkBlock.id), {self.POS_REGISTER}, {}, false);

    self:setActiveBlock(checkBlock);
    local varRegs = {};
    for i, id in ipairs(statement.ids) do
        varRegs[i] = self:getVarRegister(statement.scope, id, funcDepth)
    end



    -- Keep the control result separate from the visible first loop variable.
    -- Native multiple assignment preserves nils and pads missing results.
    local resultRegs = {exprregs[3]};
    local resultTargets = {self:registerAssignment(exprregs[3])};
    for i = 2, #varRegs do
        resultRegs[i] = varRegs[i];
        resultTargets[i] = self:registerAssignment(varRegs[i]);
    end

    self:addStatement(Ast.AssignmentStatement(resultTargets, {
        Ast.FunctionCallExpression(self:register(exprregs[1]), {
            self:register(exprregs[2]),
            self:register(exprregs[3]),
        })
    }), resultRegs, {exprregs[1], exprregs[2], exprregs[3]}, true);



    self:addStatement(Ast.AssignmentStatement({
        self:posAssignment()
    }, {
        Ast.OrExpression(Ast.AndExpression(self:register(exprregs[3]), Ast.NumberExpression(bodyBlock.id)), Ast.NumberExpression(finalBlock.id))
    }), {self.POS_REGISTER}, {exprregs[3]}, false);

    self:setActiveBlock(bodyBlock);
    self:addStatement(self:copyRegisters({varRegs[1]}, {exprregs[3]}), {varRegs[1]}, {exprregs[3]}, false);

    for i, id in ipairs(statement.ids) do
        if(self:isUpvalue(statement.scope, id)) then
            local varreg = varRegs[i];
            local tmpReg = self:allocRegister(false);
            self:addStatement(self:setRegister(tmpReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.allocUpvalFunction), {})), {tmpReg}, {}, false);
            self:addStatement(self:setUpvalueMember(self:register(tmpReg), self:register(varreg)), {}, {tmpReg, varreg}, true);
            self:addStatement(self:copyRegisters({varreg}, {tmpReg}), {varreg}, {tmpReg}, false);
            self:freeRegister(tmpReg, false);
        end
    end

    self:compileBlock(statement.body, funcDepth);
    self:addStatement(self:setPos(checkBlock.id), {self.POS_REGISTER}, {}, false);
    self:setActiveBlock(finalBlock);

    for i, _ in ipairs(exprregs) do
        self:freeRegister(exprregs[i], true)
    end
end;

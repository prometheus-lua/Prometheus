-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- while_statement.lua
--
-- This Script contains the statement handler for the WhileStatement

local Ast = require("prometheus.ast");

return function(self, statement, funcDepth)
    local innerBlock = self:createBlock();
    local finalBlock = self:createBlock();
    local checkBlock = self:createBlock();

    statement.__start_block = checkBlock;
    statement.__final_block = finalBlock;

    self:addStatement(self:setPos(checkBlock.id), {self.POS_REGISTER}, {}, false);

    self:setActiveBlock(checkBlock);
    local conditionReg = self:compileExpression(statement.condition, funcDepth, 1)[1];
    self:addStatement(self:setRegister(self.POS_REGISTER, Ast.OrExpression(Ast.AndExpression(self:register(conditionReg), Ast.NumberExpression(innerBlock.id)), Ast.NumberExpression(finalBlock.id))), {self.POS_REGISTER}, {conditionReg}, false);
    self:freeRegister(conditionReg, false);

    self:setActiveBlock(innerBlock);
    self:compileBlock(statement.body, funcDepth);
    self:addStatement(self:setPos(checkBlock.id), {self.POS_REGISTER}, {}, false);
    self:setActiveBlock(finalBlock);
end;

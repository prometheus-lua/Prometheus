-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- compile_top.lua
--
-- This Script contains the compilation of the top node, function, and block.

local Ast = require("prometheus.ast");
local util = require("prometheus.util");
local visitast = require("prometheus.visitast");

local lookupify = util.lookupify;
local AstKind = Ast.AstKind;

return function(Compiler)
    function Compiler:compileTopNode(node)
        local startBlock = self:createBlock();
        local scope = startBlock.scope;
        self.startBlockId = startBlock.id;
        self:setActiveBlock(startBlock);

        local varAccessLookup = lookupify{
            AstKind.AssignmentVariable,
            AstKind.VariableExpression,
            AstKind.FunctionDeclaration,
            AstKind.LocalFunctionDeclaration,
        }

        local functionLookup = lookupify{
            AstKind.FunctionDeclaration,
            AstKind.LocalFunctionDeclaration,
            AstKind.FunctionLiteralExpression,
            AstKind.TopNode,
        }
        visitast(node, function(node, data)
            if node.kind == AstKind.Block then
                node.scope.__depth = data.functionData.depth;
            end

            if varAccessLookup[node.kind] then
                if not node.scope.isGlobal then
                    if node.scope.__depth < data.functionData.depth then
                        if not self:isUpvalue(node.scope, node.id) then
                            self:makeUpvalue(node.scope, node.id);
                        end
                    end
                end
            end
        end, nil, nil)

        self.varargReg = self:allocRegister(true);
        scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
        scope:addReferenceToHigherScope(self.scope, self.selectVar);
        scope:addReferenceToHigherScope(self.scope, self.unpackVar);
        self:addStatement(self:setRegister(scope, self.varargReg, Ast.VariableExpression(self.containerFuncScope, self.argsVar)), {self.varargReg}, {}, false);

        self:compileBlock(node.body, 0);
        if(self.activeBlock.advanceToNextBlock) then
            self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false);
            self:addStatement(self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})), {self.RETURN_REGISTER}, {}, false)
            self.activeBlock.advanceToNextBlock = false;
        end

        self:resetRegisters();
    end

    function Compiler:compileFunction(node, funcDepth)
        funcDepth = funcDepth + 1;
        local oldActiveBlock = self.activeBlock;

        local upperVarargReg = self.varargReg;
        self.varargReg = nil;

        local upvalueExpressions = {};
        local upvalueIds = {};
        local usedRegs = {};

        local oldGetUpvalueId = self.getUpvalueId;
        self.getUpvalueId = function(self, scope, id)
            if(not upvalueIds[scope]) then
                upvalueIds[scope] = {};
            end
            if(upvalueIds[scope][id]) then
                return upvalueIds[scope][id];
            end
            local scopeFuncDepth = self.scopeFunctionDepths[scope];
            local expression;
            if(scopeFuncDepth == funcDepth) then
                oldActiveBlock.scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
                expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {});
            elseif(scopeFuncDepth == funcDepth - 1) then
                local varReg = self:getVarRegister(scope, id, scopeFuncDepth, nil);
                expression = self:register(oldActiveBlock.scope, varReg);
                table.insert(usedRegs, varReg);
            else
                local higherId = oldGetUpvalueId(self, scope, id);
                oldActiveBlock.scope:addReferenceToHigherScope(self.containerFuncScope, self.currentUpvaluesVar);
                expression = Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar), Ast.NumberExpression(higherId));
            end
            table.insert(upvalueExpressions, Ast.TableEntry(expression));
            local uid = #upvalueExpressions;
            upvalueIds[scope][id] = uid;
            return uid;
        end

        local block = self:createBlock();
        self:setActiveBlock(block);
        local scope = self.activeBlock.scope;
        self:pushRegisterUsageInfo();
        for i, arg in ipairs(node.args) do
            if(arg.kind == AstKind.VariableExpression) then
                if(self:isUpvalue(arg.scope, arg.id)) then
                    scope:addReferenceToHigherScope(self.scope, self.allocUpvalFunction);
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil);
                    self:addStatement(self:setRegister(scope, argReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {})), {argReg}, {}, false);
                    self:addStatement(self:setUpvalueMember(scope, self:register(scope, argReg), Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar), Ast.NumberExpression(i))), {}, {argReg}, true);
                else
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil);
                    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
                    self:addStatement(self:setRegister(scope, argReg, Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, self.argsVar), Ast.NumberExpression(i))), {argReg}, {}, false);
                end
            else
                self.varargReg = self:allocRegister(true);
                scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
                scope:addReferenceToHigherScope(self.scope, self.selectVar);
                scope:addReferenceToHigherScope(self.scope, self.unpackVar);
                self:addStatement(self:setRegister(scope, self.varargReg, Ast.TableConstructorExpression({
                    Ast.TableEntry(Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.selectVar), {
                        Ast.NumberExpression(i);
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), {
                            Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                        });
                    })),
                })), {self.varargReg}, {}, false);
            end
        end

        self:compileBlock(node.body, funcDepth);
        if(self.activeBlock.advanceToNextBlock) then
            self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false);
            self:addStatement(self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})), {self.RETURN_REGISTER}, {}, false);
            self.activeBlock.advanceToNextBlock = false;
        end

        if(self.varargReg) then
            self:freeRegister(self.varargReg, true);
        end
        self.varargReg = upperVarargReg;
        self.getUpvalueId = oldGetUpvalueId;

        self:popRegisterUsageInfo();
        self:setActiveBlock(oldActiveBlock);

        local scope = self.activeBlock.scope;

        local retReg = self:allocRegister(false);

        local isVarargFunction = #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression;

        local retrieveExpression
        if isVarargFunction then
            scope:addReferenceToHigherScope(self.scope, self.createVarargClosureVar);
            retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.createVarargClosureVar), {
                Ast.NumberExpression(block.id),
                Ast.TableConstructorExpression(upvalueExpressions)
            });
        else
            local varScope, var = self:getCreateClosureVar(#node.args + math.random(0, 5));
            scope:addReferenceToHigherScope(varScope, var);
            retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(varScope, var), {
                Ast.NumberExpression(block.id),
                Ast.TableConstructorExpression(upvalueExpressions)
            });
        end

        self:addStatement(self:setRegister(scope, retReg, retrieveExpression), {retReg}, usedRegs, false);
        return retReg;
    end

    function Compiler:compileBlock(block, funcDepth)
        for i, stat in ipairs(block.statements) do
            self:compileStatement(stat, funcDepth);
        end

        local scope = self.activeBlock.scope;
        for id, name in ipairs(block.scope.variables) do
            local varReg = self:getVarRegister(block.scope, id, funcDepth, nil);
            if self:isUpvalue(block.scope, id) then
                scope:addReferenceToHigherScope(self.scope, self.freeUpvalueFunc);
                self:addStatement(self:setRegister(scope, varReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.freeUpvalueFunc), {
                    self:register(scope, varReg)
                })), {varReg}, {varReg}, false);
            else
                self:addStatement(self:setRegister(scope, varReg, Ast.NilExpression()), {varReg}, {}, false);
            end
            self:freeRegister(varReg, true);
        end
    end
end


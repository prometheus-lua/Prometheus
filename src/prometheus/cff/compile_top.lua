-- This Script is Part of the Prometheus Obfuscator by levno-710
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
        if self.nativeExpressions then self:prepareNativeExpressions(); end
        local startBlock = self:createBlock();
        self.startBlockId = startBlock.id;
        self:setActiveBlock(startBlock);

        local varAccessLookup = lookupify{
            AstKind.AssignmentVariable,
            AstKind.AssignmentGlobalVariable,
            AstKind.VariableExpression,
            AstKind.GlobalVariableExpression,
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
        self:addStatement(self:setRegister(self.varargReg, Ast.VariableExpression(self.argsVar)), {self.varargReg}, {}, false);

        self:compileBlock(node.body, 0);
        if(self.activeBlock.advanceToNextBlock) then
            self:addStatement(self:setPos(nil), {self.POS_REGISTER}, {}, false);
            self:addStatement(self:setReturn(self:pack({})), {self.RETURN_REGISTER}, {}, false)
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
                expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.allocUpvalFunction), {});
            elseif(scopeFuncDepth == funcDepth - 1) then
                local varReg = self:getVarRegister(scope, id, scopeFuncDepth, nil);
                expression = self:register(varReg);
                table.insert(usedRegs, varReg);
            else
                local higherId = oldGetUpvalueId(self, scope, id);
                expression = Ast.IndexExpression(Ast.VariableExpression(self.currentUpvaluesVar), Ast.NumberExpression(higherId));
            end
            table.insert(upvalueExpressions, Ast.TableEntry(expression));
            local uid = #upvalueExpressions;
            upvalueIds[scope][id] = uid;
            return uid;
        end

        local block = self:createBlock();
        self:setActiveBlock(block);
        self:pushRegisterUsageInfo();
        for i, arg in ipairs(node.args) do
            if(arg.kind == AstKind.VariableExpression or arg.kind == AstKind.GlobalVariableExpression) then
                if(self:isUpvalue(arg.scope, arg.id)) then
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil);
                    self:addStatement(self:setRegister(argReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.allocUpvalFunction), {})), {argReg}, {}, false);
                    self:addStatement(self:setUpvalueMember(self:register(argReg), Ast.IndexExpression(Ast.VariableExpression(self.argsVar), Ast.NumberExpression(i))), {}, {argReg}, true);
                else
                    local argReg = self:getVarRegister(arg.scope, arg.id, funcDepth, nil);
                    self:addStatement(self:setRegister(argReg, Ast.IndexExpression(Ast.VariableExpression(self.argsVar), Ast.NumberExpression(i))), {argReg}, {}, false);
                end
            else
                self.varargReg = self:allocRegister(true);
                self:addStatement(self:setRegister(self.varargReg, self:pack({
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.selectVar), {
                        Ast.NumberExpression(i);
                        Ast.FunctionCallExpression(self:unpack(), {
                            Ast.VariableExpression(self.argsVar),
                        });
                    }),
                })), {self.varargReg}, {}, false);
            end
        end

        self:compileBlock(node.body, funcDepth);
        if(self.activeBlock.advanceToNextBlock) then
            self:addStatement(self:setPos(nil), {self.POS_REGISTER}, {}, false);
            self:addStatement(self:setReturn(self:pack({})), {self.RETURN_REGISTER}, {}, false);
            self.activeBlock.advanceToNextBlock = false;
        end

        if(self.varargReg) then
            self:freeRegister(self.varargReg, true);
        end
        self.varargReg = upperVarargReg;
        self.getUpvalueId = oldGetUpvalueId;

        self:popRegisterUsageInfo();
        self:setActiveBlock(oldActiveBlock);
        local retReg = self:allocRegister(false);

        local isVarargFunction = #node.args > 0 and node.args[#node.args].kind == AstKind.VarargExpression;

        local retrieveExpression
        if isVarargFunction then
            retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(self.createVarargClosureVar), {
                Ast.NumberExpression(block.id),
                Ast.TableConstructorExpression(upvalueExpressions),
                self:env()
            });
        else
            local var = self:getCreateClosureVar(#node.args + math.random(0, 5));
            retrieveExpression = Ast.FunctionCallExpression(Ast.VariableExpression(var), {
                Ast.NumberExpression(block.id),
                Ast.TableConstructorExpression(upvalueExpressions),
                self:env()
            });
        end

        self:addStatement(self:setRegister(retReg, retrieveExpression), {retReg}, usedRegs, false);
        return retReg;
    end

    function Compiler:compileBlock(block, funcDepth)
        for i, stat in ipairs(block.statements) do
            self:compileStatement(stat, funcDepth);
        end
        for id, name in ipairs(block.scope.variables) do
            local varReg = self:getVarRegister(block.scope, id, funcDepth, nil);
            if self:isUpvalue(block.scope, id) then
                self:addStatement(self:setRegister(varReg, Ast.FunctionCallExpression(Ast.VariableExpression(self.freeUpvalueFunc), {
                    self:register(varReg)
                })), {varReg}, {varReg}, false);
            else
                self:addStatement(self:setRegister(varReg, Ast.NilExpression()), {varReg}, {}, false);
            end
            self:freeRegister(varReg, true);
        end
    end
end


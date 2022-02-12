-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- compiler.lua
-- This Script contains the new Compiler

-- The max Number of variables used as registers
local MAX_REGS = 100;

local Compiler = {};

local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger");
local util = require("prometheus.util");

local lookupify = util.lookupify;
local AstKind = Ast.AstKind;

local unpack = unpack or table.unpack;

function Compiler:new()
    local compiler = {
        blocks = {};
        registers = {
        };
        activeBlock = nil;
        registersForVar = {};
        maxUsedRegister = 0;
        registerVars = {};

        VAR_REGISTER = newproxy(false);
        RETURN_ALL = newproxy(false); 
        POS_REGISTER = newproxy(false);
        RETURN_REGISTER = newproxy(false);

        BIN_OPS = lookupify{
            AstKind.OrExpression,
            AstKind.AndExpression,
            AstKind.LessThanExpression,
            AstKind.GreaterThanExpression,
            AstKind.LessThanOrEqualsExpression,
            AstKind.GreaterThanOrEqualsExpression,
            AstKind.NotEqualsExpression,
            AstKind.EqualsExpression,
            AstKind.StrCatExpression,
            AstKind.AddExpression,
            AstKind.SubExpression,
            AstKind.MulExpression,
            AstKind.DivExpression,
            AstKind.ModExpression,
            AstKind.NegateExpression,
            AstKind.PowExpression,
        }
    };

    setmetatable(compiler, self);
    self.__index = self;

    return compiler;
end

function Compiler:createBlock()
    local id = #self.blocks + 1;
    local scope = Scope:new(self.containerFuncScope);
    local block = {
        id = id;
        statements = {

        };
        scope = scope;
        advanceToNextBlock = true;
    };
    table.insert(self.blocks, block);
    return block;
end

function Compiler:setActiveBlock(block)
    self.activeBlock = block;
end

function Compiler:addStatement(statement, writes, reads, doNotMove)
    table.insert(self.activeBlock.statements, {
        statement = statement,
        writes = lookupify(writes),
        reads = lookupify(reads),
        doNotMove = doNotMove or false,
    });
end

function Compiler:compile(ast)
    self.blocks = {};
    self.registers = {};
    self.activeBlock = nil;
    self.registersForVar = {};
    self.maxUsedRegister = 0;
    self.registerVars = {};


    local newGlobalScope = Scope:newGlobal();
    local psc = Scope:new(newGlobalScope, nil);

    local _, getfenvVar = newGlobalScope:resolve("getfenv");
    local _, tableVar  = newGlobalScope:resolve("table");
    local _, unpackVar = newGlobalScope:resolve("unpack");

    self.scope = Scope:new(psc);
    self.envVar = self.scope:addVariable();
    self.containerFuncVar = self.scope:addVariable();
    self.unpackVar = self.scope:addVariable();

    self.containerFuncScope = Scope:new(self.scope);
    self.whileScope = Scope:new(self.containerFuncScope);

    self.posVar = self.containerFuncScope:addVariable();
    self.argsVar = self.containerFuncScope:addVariable();
    self.regsVar = self.containerFuncScope:addVariable();
    self.returnVar  = self.containerFuncScope:addVariable();

    
    self.createClosureVar = self.scope:addVariable();
    local createClosureScope = Scope:new(self.scope);
    local createClosurePosArg = createClosureScope:addVariable();

    local createClosureSubScope =Scope:new(createClosureScope);

    -- Invoke Compiler
    self:compileTopNode(ast);

    -- Reference to Higher Scopes
    createClosureScope:addReferenceToHigherScope(self.scope, self.containerFuncVar);
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)

    -- Emit Code
    local functionNode = Ast.FunctionLiteralExpression({
        Ast.VariableExpression(self.scope, self.envVar),
        Ast.VariableExpression(self.scope, self.unpackVar),
        Ast.VariableExpression(self.scope, self.containerFuncVar),
        Ast.VariableExpression(self.scope, self.createClosureVar),
    }, Ast.Block({
        Ast.AssignmentStatement({
            Ast.AssignmentVariable(self.scope, self.containerFuncVar),
            Ast.AssignmentVariable(self.scope, self.createClosureVar)
        }, {
            Ast.FunctionLiteralExpression({
                Ast.VariableExpression(self.containerFuncScope, self.posVar),
                Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                Ast.VariableExpression(self.containerFuncScope, self.regsVar)
            }, self:emitContainerFuncBody());

            Ast.FunctionLiteralExpression({Ast.VariableExpression(createClosureScope, createClosurePosArg)},
                Ast.Block({
                    Ast.ReturnStatement{
                        Ast.FunctionLiteralExpression({
                            Ast.VarargExpression();
                        },
                        Ast.Block({
                            Ast.ReturnStatement{
                                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.containerFuncVar), {
                                    Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                    Ast.TableConstructorExpression({Ast.TableEntry(Ast.VarargExpression())});
                                    Ast.TableConstructorExpression({}); -- Registers
                                })
                            }
                        }, createClosureSubScope)
                        );
                    }
                }, self.containerFuncScope)
            );

        });

        Ast.ReturnStatement{
            Ast.FunctionCallExpression(Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.createClosureVar), {
                    Ast.NumberExpression(self.startBlockId);
                }), {});
        }
    }, self.scope));

    return Ast.TopNode(Ast.Block({
        Ast.ReturnStatement{Ast.FunctionCallExpression(functionNode, {
            Ast.FunctionCallExpression(Ast.VariableExpression(newGlobalScope, getfenvVar), {});
            Ast.OrExpression(Ast.VariableExpression(newGlobalScope, unpackVar), Ast.IndexExpression(Ast.VariableExpression(newGlobalScope, tableVar), Ast.StringExpression("unpack")));
        })};
    }, psc), newGlobalScope);
end

function Compiler:emitContainerFuncBody()
    local tableEntries = {};

    util.shuffle(self.blocks);

    for _, block in pairs(self.blocks) do
        local id = block.id;
        local blockstats = block.statements;

        if(block.advanceToNextBlock) then
            table.insert(block.statements, self:jmp(block.scope, id + 1));
        end

        -- Shuffle Blockstats
        for i = 2, #blockstats do
            local stat = blockstats[i];
            if not stat.doNotMove then
                local reads = stat.reads;
                local writes = stat.writes;
                local maxShift = 0;
                for shift = 1, i - 1 do
                    local stat2 = blockstats[i - shift];

                    if stat2.doNotMove then
                        break;
                    end

                    local reads2 = stat2.reads;
                    local writes2 = stat2.writes;
                    local f = true;

                    for r, b in pairs(reads2) do
                        if(writes[r]) then
                            f = false;
                            break;
                        end
                    end

                    if f then
                        for r, b in pairs(writes2) do
                            if(writes[r]) then
                                f = false;
                                break;
                            end
                            if(reads[r]) then
                                f = false;
                                break;
                            end
                        end
                    end

                    if not f then
                        break
                    end

                    maxShift = shift;
                end

                local shift = math.random(0, maxShift);
                for j = 1, shift do
                    blockstats[i - j], blockstats[i - j + 1] = blockstats[i - j + 1], blockstats[i - j];
                end
            end
        end

        blockstats = {};
        for i, stat in ipairs(block.statements) do
            table.insert(blockstats, stat.statement);
        end

        table.insert(tableEntries, Ast.KeyedTableEntry(Ast.NumberExpression(id), Ast.FunctionLiteralExpression({},
            Ast.Block(blockstats, block.scope)
        )));
    end

    local tableVar = self.containerFuncScope:addVariable();

    self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar, 1);
    self.whileScope:addReferenceToHigherScope(self.containerFuncScope, tableVar);
    self.whileScope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
 
    self.containerFuncScope:addReferenceToHigherScope(self.scope, self.unpackVar);

    local tmpScope = Scope:new(self.whileScope);

    local declarations = {
        tableVar,
        self.returnVar,
    }

    for i, var in pairs(self.registerVars) do
        if(i ~= MAX_REGS) then
            table.insert(declarations, var);
        end
    end

    local stats = {
        Ast.LocalVariableDeclaration(self.containerFuncScope, util.shuffle(declarations), {});
        Ast.AssignmentStatement({Ast.AssignmentVariable(self.containerFuncScope, tableVar)}, {Ast.TableConstructorExpression(tableEntries)});
        Ast.WhileStatement(Ast.Block({
            Ast.FunctionCallStatement(
                    Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, tableVar), Ast.VariableExpression(self.containerFuncScope, self.posVar)), {}
            );
        }, self.whileScope), Ast.VariableExpression(self.containerFuncScope, self.posVar));
        Ast.ReturnStatement{
            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), {
                Ast.VariableExpression(self.containerFuncScope, self.returnVar)
            });
        }
    }

    if self.maxUsedRegister >= MAX_REGS then
        table.insert(stats, 1, Ast.LocalVariableDeclaration(self.containerFuncScope, {self.registerVars[MAX_REGS]}, {Ast.TableConstructorExpression({})}));
    end

    return Ast.Block(stats, self.containerFuncScope);
end

function Compiler:freeRegister(id, force)
    if force or not (self.registers[id] == self.VAR_REGISTER) then
        self.registers[id] = false
    end
end

function Compiler:allocRegister(isVar, isUpval)

    -- POS register can be temporarily used
    if not isVar and not self.registers[self.POS_REGISTER] then
        self.registers[self.POS_REGISTER] = true;
        return self.POS_REGISTER;
    end

    -- RETURN register can be temporarily used
    if not isVar and not self.registers[self.RETURN_REGISTER] then
        self.registers[self.RETURN_REGISTER] = true;
        return self.RETURN_REGISTER;
    end

    local id = 0;
    repeat
        id = id + 1;
    until not self.registers[id];

    if id > self.maxUsedRegister then
        self.maxUsedRegister = id;
    end

    if(isVar) then
        self.registers[id] = self.VAR_REGISTER;
    else
        self.registers[id] = true
    end
    return id;
end

function Compiler:getVarRegister(scope, id, potentialId)
    if(not self.registersForVar[scope]) then
        self.registersForVar[scope] = {};
    end

    local reg = self.registersForVar[scope][id];
    if not reg then
        if potentialId and self.registers[potentialId] ~= self.VAR_REGISTER and potentialId ~= self.POS_REGISTER and potentialId ~= self.RETURN_REGISTER then
            self.registers[potentialId] = self.VAR_REGISTER;
            reg = potentialId;
        else
            reg = self:allocRegister(true);
        end
        self.registersForVar[scope][id] = reg;
    end
    return reg;
end

function Compiler:getRegisterVarId(id)
    local varId = self.registerVars[id];
    if not varId then
        varId = self.containerFuncScope:addVariable();
        self.registerVars[id] = varId;
    end
    return varId;
end

-- Maybe convert ids to strings
function Compiler:register(scope, id)
    if id == self.POS_REGISTER then
        return self:pos(scope);
    end

    if id == self.RETURN_REGISTER then
        return self:getReturn(scope);
    end

    if id < MAX_REGS then
        local vid = self:getRegisterVarId(id);
        scope:addReferenceToHigherScope(self.containerFuncScope, vid);
        return Ast.VariableExpression(self.containerFuncScope, vid);
    end

    local vid = self:getRegisterVarId(MAX_REGS);
    scope:addReferenceToHigherScope(self.containerFuncScope, vid);
    return Ast.IndexExpression(Ast.VariableExpression(self.containerFuncScope, vid), Ast.NumberExpression(id));
end

function Compiler:registerList(scope, ids)
    local l = {};
    for i, id in ipairs(ids) do
        table.insert(l, self:register(scope, id));
    end
    return l;
end

function Compiler:registerAssignment(scope, id)
    if id == self.POS_REGISTER then
        return self:posAssignment(scope);
    end
    if id == self.RETURN_REGISTER then
        return self:returnAssignment(scope);
    end

    if id < MAX_REGS then
        local vid = self:getRegisterVarId(id);
        scope:addReferenceToHigherScope(self.containerFuncScope, vid);
        return Ast.AssignmentVariable(self.containerFuncScope, vid);
    end

    local vid = self:getRegisterVarId(MAX_REGS);
    scope:addReferenceToHigherScope(self.containerFuncScope, vid);
    return Ast.AssignmentIndexing(Ast.VariableExpression(self.containerFuncScope, vid), Ast.NumberExpression(id));
end

-- Maybe convert ids to strings
function Compiler:setRegister(scope, id, val)
    return Ast.AssignmentStatement({
        self:registerAssignment(scope, id)
    }, {
        val
    });
end

function Compiler:setRegisters(scope, ids, vals)
    local idStats = {};
    for i, id in ipairs(ids) do
        table.insert(idStats, self:registerAssignment(scope, id));
    end

    return Ast.AssignmentStatement(idStats, vals);
end

function Compiler:copyRegisters(scope, to, from)
    local idStats = {};
    local vals    = {};
    for i, id in ipairs(to) do
        local from = from[i];
        if(from ~= id) then
            table.insert(idStats, self:registerAssignment(scope, id));
            table.insert(vals, self:register(scope, from));
        end
    end

    if(#idStats > 0 and #vals > 0) then
        return Ast.AssignmentStatement(idStats, vals);
    end
end

function Compiler:resetRegisters()
    self.registers = {};
end

function Compiler:pos(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.VariableExpression(self.containerFuncScope, self.posVar);
end

function Compiler:posAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentVariable(self.containerFuncScope, self.posVar);
end

function Compiler:args(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
    return Ast.VariableExpression(self.containerFuncScope, self.argsVar);
end

function Compiler:unpack(scope)
    scope:addReferenceToHigherScope(self.scope, self.unpackVar);
    return Ast.VariableExpression(self.scope, self.unpackVar);
end

function Compiler:env(scope)
    scope:addReferenceToHigherScope(self.scope, self.envVar);
    return Ast.VariableExpression(self.scope, self.envVar);
end

function Compiler:jmp(scope, to)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentStatement({Ast.AssignmentVariable(self.containerFuncScope, self.posVar)},{Ast.NumberExpression(to)});
end

function Compiler:setPos(scope, val)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentStatement({Ast.AssignmentVariable(self.containerFuncScope, self.posVar)}, {Ast.NumberExpression(val) or Ast.NilExpression()});
end

function Compiler:setReturn(scope, val)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.AssignmentStatement({Ast.AssignmentVariable(self.containerFuncScope, self.returnVar)}, {val});
end

function Compiler:getReturn(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.VariableExpression(self.containerFuncScope, self.returnVar);
end

function Compiler:returnAssignment(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.returnVar);
    return Ast.AssignmentVariable(self.containerFuncScope, self.returnVar);
end

function Compiler:compileTopNode(node)
    -- Create Initial Block
    local startBlock = self:createBlock();
    self.startBlockId = startBlock.id;
    self:setActiveBlock(startBlock);

    -- Compile Block
    self:compileBlock(node.body, 0);
    if(self.activeBlock.advanceToNextBlock) then
        self.activeBlock.advanceToNextBlock = false;
        self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false);
        self:addStatement(self:setReturn(self.activeBlock.scope, Ast.TableConstructorExpression({})), {self.RETURN_REGISTER}, {})
    end

    self:resetRegisters();
end

function Compiler:compileBlock(block, funcDepth)
    for i, stat in ipairs(block.statements) do
        self:compileStatement(stat, funcDepth);
    end
end

function Compiler:compileStatement(statement, funcDepth)
    local scope = self.activeBlock.scope;

    -- Return Statement
    if(statement.kind == AstKind.ReturnStatement) then
        local entries = {};
        local regs = {};

        for i, expr in ipairs(statement.args) do
            if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(entries, Ast.TableEntry(Ast.FunctionCallExpression(
                    self:unpack(scope),
                    {self:register(scope, reg)})));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(entries, Ast.TableEntry(self:register(scope, reg)));
                table.insert(regs, reg);
            end
        end

        for _, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        self:addStatement(self:setReturn(scope, Ast.TableConstructorExpression(entries)), {self.RETURN_REGISTER}, regs, true);
        self.activeBlock.advanceToNextBlock = false;
        self:addStatement(self:setPos(self.activeBlock.scope, nil), {self.POS_REGISTER}, {}, false);

        return;
    end

    -- Local Variable Declaration
    if(statement.kind == AstKind.LocalVariableDeclaration) then
        local exprregs = {};
        for i, expr in ipairs(statement.expressions) do
            if(i == #statement.expressions and #statement.ids > #statement.expressions) then
                local regs = self:compileExpression(expr, funcDepth, #statement.ids - #statement.expressions + 1);

                for i, reg in ipairs(regs) do
                    table.insert(exprregs, reg);
                end
            else
                if statement.ids[i] or expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression then
                    local reg = self:compileExpression(expr, funcDepth, 1)[1];
                    table.insert(exprregs, reg);
                end
            end
        end

        local varregs = {};
        for i, id in ipairs(statement.ids) do
            table.insert(varregs, self:getVarRegister(statement.scope, id, exprregs[i]));
            self:freeRegister(exprregs[i], false);
        end

        self:addStatement(self:copyRegisters(scope, varregs, exprregs), varregs, exprregs);
        return;
    end

    -- Function call Statement
    if(statement.kind == AstKind.FunctionCallStatement) then
        local baseReg = self:compileExpression(statement.base, funcDepth, 1)[1];
        local retReg  = self:allocRegister(false, false);
        local argRegs = {};

        -- TODO: Function call multi return pass
        for i, expr in ipairs(statement.args) do
            table.insert(argRegs, self:compileExpression(expr, funcDepth, 1)[1]);
        end

        self:addStatement(self:setRegister(scope, retReg, Ast.FunctionCallExpression(self:register(scope, baseReg), self:registerList(scope, argRegs))), {retReg}, {baseReg, argRegs}, true);
        self:freeRegister(baseReg, false);
        self:freeRegister(retReg, false);
        for i, reg in ipairs(argRegs) do
            self:freeRegister(reg, false);
        end
        
        return;
    end

    -- Pass self Function Call Statement
    if(statement.kind == AstKind.PassSelfFunctionCallStatement) then
        local baseReg = self:compileExpression(statement.base, funcDepth, 1)[1];
        local tmpReg  = self:allocRegister(false, false);
        local argRegs = { baseReg };

        -- TODO: Function call multi return pass
        for i, expr in ipairs(statement.args) do
            table.insert(argRegs, self:compileExpression(expr, funcDepth, 1)[1]);
        end

        self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(statement.passSelfFunctionName)), {tmpReg}, {});
        self:addStatement(self:setRegister(scope, tmpReg, Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, tmpReg))), {tmpReg}, {tmpReg, baseReg});

        self:addStatement(self:setRegister(scope, tmpReg, Ast.FunctionCallExpression(self:register(scope, tmpReg), self:registerList(scope, argRegs))), {tmpReg}, {tmpReg, unpack(argRegs)}, true);
        self:freeRegister(baseReg, false);
        self:freeRegister(tmpReg, false);
        for i, reg in ipairs(argRegs) do
            self:freeRegister(reg, false);
        end
        
        return;
    end

    -- TODO

    logger:error(string.format("%s is not a compileable statement!", statement.kind));
end

function Compiler:compileExpression(expression, funcDepth, numReturns)
    local scope = self.activeBlock.scope;

    -- String Expression
    if(expression.kind == AstKind.StringExpression) then
        local regs = {};
        for i=1, numReturns, 1 do
            regs[i] = self:allocRegister();
            if(i == 1) then
                self:addStatement(self:setRegister(scope, regs[i], Ast.StringExpression(expression.value)), {regs[i]}, {});
            else
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- Number Expression
    if(expression.kind == AstKind.NumberExpression) then
        local regs = {};
        for i=1, numReturns do
            regs[i] = self:allocRegister();
            if(i == 1) then
               self:addStatement(self:setRegister(scope, regs[i], Ast.NumberExpression(expression.value)), {regs[i]}, {});
            else
               self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- Boolean Expression
    if(expression.kind == AstKind.BooleanExpression) then
        local regs = {};
        for i=1, numReturns do
            regs[i] = self:allocRegister();
            if(i == 1) then
               self:addStatement(self:setRegister(scope, regs[i], Ast.BooleanExpression(expression.value)), {regs[i]}, {});
            else
               self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- Nil Expression
    if(expression.kind == AstKind.NilExpression) then
        local regs = {};
        for i=1, numReturns do
            regs[i] = self:allocRegister();
            self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
        end
        return regs;
    end

    -- Variable Expression
    if(expression.kind == AstKind.VariableExpression) then
        local regs = {};
        for i=1, numReturns do
            if(i == 1) then
                -- TODO: Implement Upvalues
                if(expression.scope.isGlobal) then
                    -- Global Variable
                    regs[i] = self:allocRegister(false, false);
                    local tmpReg = self:allocRegister(false, false);
                    self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(expression.scope:getVariableName(expression.id))), {tmpReg}, {});
                    self:addStatement(self:setRegister(scope, regs[i], Ast.IndexExpression(self:env(scope), self:register(scope, tmpReg))), {regs[i]}, {tmpReg});
                    self:freeRegister(tmpReg, false);
                else
                    -- Local Variable
                    regs[i] = self:getVarRegister(expression.scope, expression.id);
                end
            else
                regs[i] = self:allocRegister();
                self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- Function call Expression
    if(expression.kind == AstKind.FunctionCallExpression) then
        local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1];
        local retRegs  = {};
        for i = 1, numReturns do
            retRegs[i] = self:allocRegister(false, false);
        end
        local argRegs = {};

        -- TODO: Function call multi return pass
        for i, expr in ipairs(expression.args) do
            table.insert(argRegs, self:compileExpression(expr, funcDepth, 1)[1]);
        end

        self:addStatement(self:setRegisters(scope, retRegs, {Ast.FunctionCallExpression(self:register(scope, baseReg), self:registerList(scope, argRegs))}), retRegs, {baseReg, unpack(argRegs)}, true);
        self:freeRegister(baseReg, false);
        for i, reg in ipairs(argRegs) do
            self:freeRegister(reg, false);
        end
        
        return retRegs;
    end

    -- Pass self Function Call Statement
    if(expression.kind == AstKind.PassSelfFunctionCallExpression) then
        local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1];
        local retRegs  = {};
        for i = 1, numReturns do
            retRegs[i] = self:allocRegister(false, false);
        end
        local tmpReg = retRegs[1] or self:allocRegister(false, false);
        local argRegs = { baseReg };

        -- TODO: Function call multi return pass
        for i, expr in ipairs(expression.args) do
            table.insert(argRegs, self:compileExpression(expr, funcDepth, 1)[1]);
        end

        self:addStatement(self:setRegister(scope, tmpReg, Ast.StringExpression(expression.passSelfFunctionName)), {tmpReg}, {});
        self:addStatement(self:setRegister(scope, tmpReg, Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, tmpReg))), {tmpReg}, {baseReg, tmpReg});

        self:addStatement(self:setRegisters(scope, retRegs, {Ast.FunctionCallExpression(self:register(scope, tmpReg), self:registerList(scope, argRegs))}), retRegs, {tmpReg, unpack(argRegs)}, true)
        self:freeRegister(baseReg, false);
        for i, reg in ipairs(argRegs) do
            self:freeRegister(reg, false);
        end
        
        return retRegs;
    end

    -- Index Expression
    if(expression.kind == AstKind.IndexExpression) then
        local regs = {};
        for i=1, numReturns do
            regs[i] = self:allocRegister();
            if(i == 1) then
                local baseReg = self:compileExpression(expression.base, funcDepth, 1)[1];
                local indexReg = self:compileExpression(expression.index, funcDepth, 1)[1];

                self:addStatement(self:setRegister(scope, regs[i], Ast.IndexExpression(self:register(scope, baseReg), self:register(scope, indexReg))), {regs[i]}, {baseReg, indexReg});
                self:freeRegister(baseReg, false);
                self:freeRegister(indexReg, false)
            else
               self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- Binary Operations
    if(self.BIN_OPS[expression.kind]) then
        local regs = {};
        for i=1, numReturns do
            regs[i] = self:allocRegister();
            if(i == 1) then
                local lhsReg = self:compileExpression(expression.lhs, funcDepth, 1)[1];
                local rhsReg = self:compileExpression(expression.rhs, funcDepth, 1)[1];

                self:addStatement(self:setRegister(scope, regs[i], Ast[expression.kind](self:register(scope, lhsReg), self:register(scope, rhsReg))), {regs[i]}, {lhsReg, rhsReg});
                self:freeRegister(rhsReg, false);
                self:freeRegister(lhsReg, false)
            else
               self:addStatement(self:setRegister(scope, regs[i], Ast.NilExpression()), {regs[i]}, {});
            end
        end
        return regs;
    end

    -- TODO

    logger:error(string.format("%s is not an compileable expression!", expression.kind));
end

return Compiler;
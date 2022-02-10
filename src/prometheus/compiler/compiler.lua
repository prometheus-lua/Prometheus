-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- compiler.lua
-- This Script contains the new Compiler

local Compiler = {};

local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger")
local AstKind = Ast.AstKind;

function Compiler:new()
    local compiler = {
        blocks = {};
        registers = {};
        activeBlock = nil;
        registersForVar = {};

        VAR_REGISTER = newproxy(false);
        RETURN_ALL = newproxy(false); 
    };

    setmetatable(compiler, self);
    self.__index = self;

    return compiler;
end

function Compiler:createBlock()
    local id = #self.blocks + 1;
    local scope = Scope:new(self.scope);
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

function Compiler:addStatement(statement)
    table.insert(self.activeBlock.statements, statement);
end

function Compiler:compile(ast)
    self.blocks = {};
    self.registers = {};
    self.activeBlock = nil;
    self.registersForVar = {};


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
    local statements = {};

    for id, block in pairs(self.blocks) do
        if(block.advanceToNextBlock) then
            table.insert(block.statements, self:jmp(block.scope, id + 1));
        end
        table.insert(statements, Ast.IfStatement(
            Ast.EqualsExpression(self:pos(self.whileScope), Ast.NumberExpression(id)),
            Ast.Block(block.statements, block.scope), {}, nil
        ));
    end

    return Ast.Block({Ast.WhileStatement(Ast.Block(statements, self.whileScope), Ast.BooleanExpression(true))}, self.containerFuncScope);
end

function Compiler:freeRegister(id, force)
    if force or not (self.registers[id] == self.VAR_REGISTER) then
        self.registers[id] = false
    end
end

function Compiler:allocRegister(isVar)
    local id = 0;
    repeat
        id = id + 1;
    until not self.registers[id];
    if(isVar) then
        self.registers[id] = self.VAR_REGISTER;
    else
        self.registers[id] = true
    end
    return id;
end

function Compiler:getVarRegister(scope, id)
    if(not self.registersForVar[scope]) then
        self.registersForVar[scope] = {};
    end

    local reg = self.registersForVar[scope][id];
    if not reg then
        reg = self:allocRegister();
        self.registersForVar[scope][id] = reg;
    end
    return reg;
end

-- Maybe convert ids to strings
function Compiler:register(scope, id)
    return Ast.IndexExpression(self:regs(scope), Ast.NumberExpression(id));
end

-- Maybe convert ids to strings
function Compiler:setRegister(scope, id, val)
    return Ast.AssignmentStatement({
        Ast.AssignmentIndexing(self:regs(scope), Ast.NumberExpression(id))
    }, {
        val
    });
end

function Compiler:resetRegisters()
    self.registers = {};
end

function Compiler:pos(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.VariableExpression(self.containerFuncScope, self.posVar);
end

function Compiler:args(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.argsVar);
    return Ast.VariableExpression(self.containerFuncScope, self.argsVar);
end

function Compiler:unpack(scope)
    scope:addReferenceToHigherScope(self.scope, self.unpackVar);
    return Ast.VariableExpression(self.scope, self.unpackVar);
end

function Compiler:regs(scope)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.regsVar);
    return Ast.VariableExpression(self.containerFuncScope, self.regsVar);
end

function Compiler:jmp(scope, to)
    scope:addReferenceToHigherScope(self.containerFuncScope, self.posVar);
    return Ast.AssignmentStatement({Ast.AssignmentVariable(self.containerFuncScope, self.posVar)},{Ast.NumberExpression(to)});
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
        self:addStatement(Ast.ReturnStatement({}));
    end

    self:resetRegisters();
end

function Compiler:compileBlock(block, funcDepth)
    for i, stat in ipairs(block.statements) do
        self:compileStatement(stat, funcDepth);
    end
end

function Compiler:compileStatement(statement, funcDepth)
    -- Return Statement
    if(statement.kind == AstKind.ReturnStatement) then
        local outExpressions = {};
        local regs = {};

        for i, expr in ipairs(statement.args) do
            if i == #statement.args and (expr.kind == AstKind.FunctionCallExpression or expr.kind == AstKind.PassSelfFunctionCallExpression) then
                local reg = self:compileExpression(expr, funcDepth, self.RETURN_ALL)[1];
                table.insert(outExpressions, Ast.FunctionCallExpression(
                    self:unpack(self.activeBlock.scope),
                    {self:register(self.activeBlock.scope, reg)}));
                table.insert(regs, reg);
            else
                local reg = self:compileExpression(expr, funcDepth, 1)[1];
                table.insert(outExpressions, self:register(self.activeBlock.scope, reg));
                table.insert(regs, reg);
            end
        end

        for _, reg in ipairs(regs) do
            self:freeRegister(reg, false);
        end

        self:addStatement(Ast.ReturnStatement(outExpressions));
        self.activeBlock.advanceToNextBlock = false;
        return;
    end

    
    -- TODO

    logger:error(string.format("%s is not a compileable statement!", statement.kind));
end

function Compiler:compileExpression(expression, funcDepth, numReturns)

    -- String Expression
    if(expression.kind == AstKind.StringExpression) then
        local regs = {};
        for i=1, numReturns, 1 do
            regs[i] = self:allocRegister();
            if(i == 1) then
                self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.StringExpression(expression.value)));
            else
                self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.NilExpression()));
            end
        end
        return regs;
    end

    -- Number Expression
    if(expression.kind == AstKind.NumberExpression) then
        local regs = {};
        for i=1, numReturns, 1 do
            regs[i] = self:allocRegister();
            if(i == 1) then
               self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.NumberExpression(expression.value)));
            else
               self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.NilExpression()));
            end
        end
        return regs;
    end

    -- Boolean Expression
    if(expression.kind == AstKind.NumberExpression) then
        local regs = {};
        for i=1, numReturns, 1 do
            regs[i] = self:allocRegister();
            if(i == 1) then
               self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.BooleanExpression(expression.value)));
            else
               self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.NilExpression()));
            end
        end
        return regs;
    end

    -- Nil Expression
    if(expression.kind == AstKind.NilExpression) then
        local regs = {};
        for i=1, numReturns, 1 do
            regs[i] = self:allocRegister();
            self:addStatement(self:setRegister(self.activeBlock.scope, regs[i], Ast.NilExpression()));
        end
        return regs;
    end


    -- TODO

    logger:error(string.format("%s is not an compileable expression!", expression.kind));
end

return Compiler;
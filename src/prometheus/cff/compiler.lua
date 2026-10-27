-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- compiler.lua
--
-- This Script is the main compiler module.

local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local util = require("prometheus.util");

local lookupify = util.lookupify;
local AstKind = Ast.AstKind;

local unpack = unpack or table.unpack;

local blockModule = require("prometheus.cff.block");
local registerModule = require("prometheus.cff.register");
local upvalueModule = require("prometheus.cff.upvalue");
local emitModule = require("prometheus.cff.emit");
local compileCoreModule = require("prometheus.cff.compile_core");

local Compiler = {};

function Compiler:new()
    local compiler = {
        blocks = {};
        registers = {};
        activeBlock = nil;
        registersForVar = {};
        usedRegisters = 0;
        maxUsedRegister = 0;
        registerVars = {};

        VAR_REGISTER = newproxy(false);
        RETURN_ALL = newproxy(false);
        POS_REGISTER = newproxy(false);
        RETURN_REGISTER = newproxy(false);
        UPVALUE = newproxy(false);

        BIN_OPS = lookupify{
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
            AstKind.PowExpression,
        };
    };

    setmetatable(compiler, self);
    self.__index = self;

    return compiler;
end

blockModule(Compiler);
registerModule(Compiler);
upvalueModule(Compiler);
emitModule(Compiler);
compileCoreModule(Compiler);
require("prometheus.cff.native")(Compiler);

function Compiler:pushRegisterUsageInfo()
    table.insert(self.registerUsageStack, {
        usedRegisters = self.usedRegisters;
        registers = self.registers;
    });
    self.usedRegisters = 0;
    self.registers = {};
end

function Compiler:popRegisterUsageInfo()
    local info = table.remove(self.registerUsageStack);
    self.usedRegisters = info.usedRegisters;
    self.registers = info.registers;
end

function Compiler:compile(ast)
    self.blocks = {};
    self.registers = {};
    self.activeBlock = nil;
    self.registersForVar = {};
    self.scopeFunctionDepths = {};
    self.maxUsedRegister = 0;
    self.usedRegisters = 0;
    self.registerVars = {};
    self.usedBlockIds = {};

    self.upvalVars = {};
    self.registerUsageStack = {};

    self.upvalsProxyLenReturn = math.random(-2^22, 2^22);

    local newGlobalScope = Scope:newGlobal();
    local psc = Scope:new(newGlobalScope, nil);

    local _, getfenvVar = newGlobalScope:resolve("getfenv");
    local _, setfenvVar = newGlobalScope:resolve("setfenv");
    local _, tableVar = newGlobalScope:resolve("table");
    local _, unpackVar = newGlobalScope:resolve("unpack");
    local _, envVar = newGlobalScope:resolve("_ENV");
    local _, newproxyVar = newGlobalScope:resolve("newproxy");
    local _, setmetatableVar = newGlobalScope:resolve("setmetatable");
    local _, getmetatableVar = newGlobalScope:resolve("getmetatable");
    local _, selectVar = newGlobalScope:resolve("select");
    local _, tonumberVar = newGlobalScope:resolve("tonumber");
    local _, errorVar = newGlobalScope:resolve("error");

    psc:addReferenceToHigherScope(newGlobalScope, getfenvVar, 3);
    psc:addReferenceToHigherScope(newGlobalScope, setfenvVar);
    psc:addReferenceToHigherScope(newGlobalScope, tableVar);
    psc:addReferenceToHigherScope(newGlobalScope, unpackVar);
    psc:addReferenceToHigherScope(newGlobalScope, envVar);
    psc:addReferenceToHigherScope(newGlobalScope, newproxyVar);
    psc:addReferenceToHigherScope(newGlobalScope, setmetatableVar);
    psc:addReferenceToHigherScope(newGlobalScope, getmetatableVar);
    psc:addReferenceToHigherScope(newGlobalScope, selectVar);
    psc:addReferenceToHigherScope(newGlobalScope, tonumberVar);
    psc:addReferenceToHigherScope(newGlobalScope, errorVar);

    self.scope = Scope:new(psc);
    self.envVar = self.scope:addVariable();
    self.getfenvVar = self.scope:addVariable();
    self.setfenvVar = self.scope:addVariable();
    self.callFunctionVar = self.scope:addVariable();
    self.containerFuncVar = self.scope:addVariable();
    self.unpackVar = self.scope:addVariable();
    self.packVar = self.scope:addVariable();
    self.unpackPackedVar = self.scope:addVariable();
    self.newproxyVar = self.scope:addVariable();
    self.setmetatableVar = self.scope:addVariable();
    self.getmetatableVar = self.scope:addVariable();
    self.selectVar = self.scope:addVariable();
    self.tonumberVar = self.scope:addVariable();
    self.errorVar = self.scope:addVariable();

    local argVar = self.scope:addVariable();

    self.containerFuncScope = Scope:new(self.scope);
    self.whileScope = Scope:new(self.containerFuncScope);

    self.posVar = self.containerFuncScope:addVariable();
    self.argsVar = self.containerFuncScope:addVariable();
    self.currentUpvaluesVar = self.containerFuncScope:addVariable();
    self.detectGcCollectVar = self.containerFuncScope:addVariable();
    self.currentEnvVar = self.containerFuncScope:addVariable();
    self.returnVar = self.containerFuncScope:addVariable();

    self.upvaluesTable = self.scope:addVariable();
    self.upvaluesReferenceCountsTable = self.scope:addVariable();
    self.allocUpvalFunction = self.scope:addVariable();
    self.currentUpvalId = self.scope:addVariable();

    self.upvaluesProxyFunctionVar = self.scope:addVariable();
    self.upvaluesGcFunctionVar = self.scope:addVariable();
    self.freeUpvalueFunc = self.scope:addVariable();

    self.createClosureVars = {};
    self.createVarargClosureVar = self.scope:addVariable();
    local createClosureScope = Scope:new(self.scope);
    local createClosurePosArg = createClosureScope:addVariable();
    local createClosureUpvalsArg = createClosureScope:addVariable();
    local createClosureEnvArg = createClosureScope:addVariable();
    local createClosureProxyObject = createClosureScope:addVariable();
    local createClosureFuncVar = createClosureScope:addVariable();

    local createClosureSubScope = Scope:new(createClosureScope);

    local upvalEntries = {};
    local upvalueIds = {};
    self.getUpvalueId = function(self, scope, id)
        local expression;
        local scopeFuncDepth = self.scopeFunctionDepths[scope];
        if(scopeFuncDepth == 0) then
            if upvalueIds[id] then
                return upvalueIds[id];
            end
            expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.allocUpvalFunction), {});
        else
            require("logger"):error("Unresolved Upvalue, this error should not occur!");
        end
        table.insert(upvalEntries, Ast.TableEntry(expression));
        local uid = #upvalEntries;
        upvalueIds[id] = uid;
        return uid;
    end

    createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar);
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureUpvalsArg, 1)
    createClosureScope:addReferenceToHigherScope(self.scope, self.upvaluesProxyFunctionVar)
    createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureProxyObject);

    self:compileTopNode(ast);

    -- VM value lists carry an explicit count: table length loses trailing nils.
    local packScope = Scope:new(self.scope);
    packScope:addReferenceToHigherScope(self.scope, self.selectVar);
    local unpackScope = Scope:new(self.scope);
    local unpackValuesVar = unpackScope:addVariable();
    unpackScope:addReferenceToHigherScope(self.scope, self.unpackVar);

    -- Keep query handling shared: a per-call closure would capture the frame's
    -- environment and delay its collection when another Cff pass wraps it.
    -- Ordinary functions receive exactly their original arguments via a tail call.
    local callScope = Scope:new(self.scope);
    local callFuncVar, callEnvVar = callScope:addVariable(), callScope:addVariable();
    callScope:addReferenceToHigherScope(self.scope, self.getfenvVar, 2);
    local getterScope = Scope:new(callScope);
    local levelVar = getterScope:addVariable();
    local currentScope = Scope:new(getterScope);
    currentScope:addReferenceToHigherScope(callScope, callEnvVar);

    local functionNodeAssignments = {
        {
            var = Ast.AssignmentVariable(self.scope, self.callFunctionVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(callScope, callFuncVar),
                Ast.VariableExpression(callScope, callEnvVar),
                Ast.VarargExpression(),
            }, Ast.Block({
                Ast.IfStatement(Ast.AndExpression(
                    Ast.VariableExpression(self.scope, self.getfenvVar),
                    Ast.EqualsExpression(Ast.VariableExpression(callScope, callFuncVar), Ast.VariableExpression(self.scope, self.getfenvVar))
                ), Ast.Block({
                    Ast.LocalVariableDeclaration(getterScope, {levelVar}, {Ast.VarargExpression()}),
                    Ast.IfStatement(Ast.OrExpression(
                        Ast.EqualsExpression(Ast.VariableExpression(getterScope, levelVar), Ast.NilExpression()),
                        Ast.EqualsExpression(Ast.VariableExpression(getterScope, levelVar), Ast.NumberExpression(1))
                    ), Ast.Block({Ast.ReturnStatement{Ast.VariableExpression(callScope, callEnvVar)}}, currentScope), {}),
                }, getterScope), {}),
                Ast.ReturnStatement{Ast.FunctionCallExpression(Ast.VariableExpression(callScope, callFuncVar), {Ast.VarargExpression()})},
            }, callScope)),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.packVar),
            val = Ast.FunctionLiteralExpression({Ast.VarargExpression()}, Ast.Block({
                Ast.ReturnStatement{Ast.TableConstructorExpression({
                    Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.FunctionCallExpression(
                        Ast.VariableExpression(self.scope, self.selectVar),
                        {Ast.StringExpression("#"), Ast.VarargExpression()})),
                    Ast.TableEntry(Ast.VarargExpression()),
                })},
            }, packScope)),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.unpackPackedVar),
            val = Ast.FunctionLiteralExpression({Ast.VariableExpression(unpackScope, unpackValuesVar)}, Ast.Block({
                Ast.ReturnStatement{Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.unpackVar), {
                    Ast.VariableExpression(unpackScope, unpackValuesVar),
                    Ast.NumberExpression(1),
                    Ast.IndexExpression(Ast.VariableExpression(unpackScope, unpackValuesVar), Ast.StringExpression("n")),
                })},
            }, unpackScope)),
        },
        {
            var = Ast.AssignmentVariable(self.scope, self.containerFuncVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(self.containerFuncScope, self.posVar),
                Ast.VariableExpression(self.containerFuncScope, self.argsVar),
                Ast.VariableExpression(self.containerFuncScope, self.currentUpvaluesVar),
                Ast.VariableExpression(self.containerFuncScope, self.detectGcCollectVar),
                Ast.VariableExpression(self.containerFuncScope, self.currentEnvVar)
            }, self:emitContainerFuncBody());
        }, {
            var = Ast.AssignmentVariable(self.scope, self.createVarargClosureVar),
            val = Ast.FunctionLiteralExpression({
                    Ast.VariableExpression(createClosureScope, createClosurePosArg),
                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
                    Ast.VariableExpression(createClosureScope, createClosureEnvArg),
                },
                Ast.Block({
                    Ast.LocalVariableDeclaration(createClosureScope, {
                        createClosureProxyObject
                    }, {
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar), {
                            Ast.VariableExpression(createClosureScope, createClosureUpvalsArg)
                        })
                    }),
                    Ast.LocalVariableDeclaration(createClosureScope, {createClosureFuncVar},{
                        Ast.FunctionLiteralExpression({
                            Ast.VarargExpression();
                        },
                        Ast.Block({
                            Ast.ReturnStatement{
                                Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.containerFuncVar), {
                                    Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                    self:pack(createClosureSubScope, {Ast.VarargExpression()}),
                                    Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
                                    Ast.VariableExpression(createClosureScope, createClosureProxyObject),
                                    self:closureEnvironment(createClosureSubScope, createClosureScope, createClosureEnvArg)
                                })
                            }
                        }, createClosureSubScope)
                        );
                    });
                    self:inheritClosureEnvironment(createClosureScope, createClosureFuncVar, createClosureEnvArg);
                    Ast.ReturnStatement{Ast.VariableExpression(createClosureScope, createClosureFuncVar)};
                }, createClosureScope)
            );
        }, {
            var = Ast.AssignmentVariable(self.scope, self.upvaluesTable),
            val = Ast.TableConstructorExpression({}),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.upvaluesReferenceCountsTable),
            val = Ast.TableConstructorExpression({}),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.allocUpvalFunction),
            val = self:createAllocUpvalFunction(),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.currentUpvalId),
            val = Ast.NumberExpression(0),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.upvaluesProxyFunctionVar),
            val = self:createUpvaluesProxyFunc(),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.upvaluesGcFunctionVar),
            val = self:createUpvaluesGcFunc(),
        }, {
            var = Ast.AssignmentVariable(self.scope, self.freeUpvalueFunc),
            val = self:createFreeUpvalueFunc(),
        },
    }

    local tbl = {
        Ast.VariableExpression(self.scope, self.callFunctionVar),
        Ast.VariableExpression(self.scope, self.packVar),
        Ast.VariableExpression(self.scope, self.unpackPackedVar),
        Ast.VariableExpression(self.scope, self.containerFuncVar),
        Ast.VariableExpression(self.scope, self.createVarargClosureVar),
        Ast.VariableExpression(self.scope, self.upvaluesTable),
        Ast.VariableExpression(self.scope, self.upvaluesReferenceCountsTable),
        Ast.VariableExpression(self.scope, self.allocUpvalFunction),
        Ast.VariableExpression(self.scope, self.currentUpvalId),
        Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar),
        Ast.VariableExpression(self.scope, self.upvaluesGcFunctionVar),
        Ast.VariableExpression(self.scope, self.freeUpvalueFunc),
    };
    for i, entry in pairs(self.createClosureVars) do
        table.insert(functionNodeAssignments, entry);
        table.insert(tbl, Ast.VariableExpression(entry.var.scope, entry.var.id));
    end

    util.shuffle(functionNodeAssignments);
    local assignmentStatLhs, assignmentStatRhs = {}, {};
    for i, v in ipairs(functionNodeAssignments) do
        assignmentStatLhs[i] = v.var;
        assignmentStatRhs[i] = v.val;
    end


    -- NEW: Position Shuffler
    local ids = util.shuffle({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11});

    local items = {
        Ast.VariableExpression(self.scope, self.envVar),
        Ast.VariableExpression(self.scope, self.unpackVar),
        Ast.VariableExpression(self.scope, self.newproxyVar),
        Ast.VariableExpression(self.scope, self.setmetatableVar),
        Ast.VariableExpression(self.scope, self.getmetatableVar),
        Ast.VariableExpression(self.scope, self.selectVar),
        Ast.VariableExpression(self.scope, argVar),
        Ast.VariableExpression(self.scope, self.tonumberVar),
        Ast.VariableExpression(self.scope, self.errorVar),
        Ast.VariableExpression(self.scope, self.getfenvVar),
        Ast.VariableExpression(self.scope, self.setfenvVar),
    }

    local astItems = {
        Ast.OrExpression(Ast.AndExpression(Ast.VariableExpression(newGlobalScope, getfenvVar), Ast.FunctionCallExpression(Ast.VariableExpression(newGlobalScope, getfenvVar), {})), Ast.VariableExpression(newGlobalScope, envVar));
        Ast.OrExpression(Ast.VariableExpression(newGlobalScope, unpackVar), Ast.IndexExpression(Ast.VariableExpression(newGlobalScope, tableVar), Ast.StringExpression("unpack")));
        Ast.VariableExpression(newGlobalScope, newproxyVar);
        Ast.VariableExpression(newGlobalScope, setmetatableVar);
        Ast.VariableExpression(newGlobalScope, getmetatableVar);
        Ast.VariableExpression(newGlobalScope, selectVar);
        Ast.TableConstructorExpression({
            Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.FunctionCallExpression(
                Ast.VariableExpression(newGlobalScope, selectVar), {Ast.StringExpression("#"), Ast.VarargExpression()})),
            Ast.TableEntry(Ast.VarargExpression());
        });
        Ast.VariableExpression(newGlobalScope, tonumberVar);
        Ast.VariableExpression(newGlobalScope, errorVar);
        Ast.VariableExpression(newGlobalScope, getfenvVar);
        Ast.VariableExpression(newGlobalScope, setfenvVar);
    }

    local functionNode = Ast.FunctionLiteralExpression({
      items[ids[1]], items[ids[2]], items[ids[3]], items[ids[4]],
      items[ids[5]], items[ids[6]], items[ids[7]], items[ids[8]], items[ids[9]],
      items[ids[10]], items[ids[11]],
      unpack(util.shuffle(tbl))
    }, Ast.Block({
        Ast.AssignmentStatement(assignmentStatLhs, assignmentStatRhs);
        Ast.ReturnStatement{
            Ast.FunctionCallExpression(Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.createVarargClosureVar), {
                    Ast.NumberExpression(self.startBlockId);
                    Ast.TableConstructorExpression(upvalEntries);
                    Ast.VariableExpression(self.scope, self.envVar);
                }), {Ast.FunctionCallExpression(self:unpack(self.scope), {Ast.VariableExpression(self.scope, argVar)})});
        }
    }, self.scope));

    return Ast.TopNode(Ast.Block({
        Ast.ReturnStatement{Ast.FunctionCallExpression(functionNode, {
            astItems[ids[1]], astItems[ids[2]], astItems[ids[3]], astItems[ids[4]],
            astItems[ids[5]], astItems[ids[6]], astItems[ids[7]], astItems[ids[8]], astItems[ids[9]],
            astItems[ids[10]], astItems[ids[11]],
        })};
    }, psc), newGlobalScope);
end

-- Each wrapper reads its own environment at entry, before tail-calling the VM.
-- The VM keeps this table in its call frame so recursion and yields are isolated.
function Compiler:closureEnvironment(scope, inheritedScope, inheritedVar)
    scope:addReferenceToHigherScope(self.scope, self.getfenvVar, 2);
    scope:addReferenceToHigherScope(inheritedScope, inheritedVar);
    return Ast.OrExpression(Ast.AndExpression(
        Ast.VariableExpression(self.scope, self.getfenvVar),
        Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.getfenvVar), {Ast.NumberExpression(1)})
    ), Ast.VariableExpression(inheritedScope, inheritedVar));
end

function Compiler:inheritClosureEnvironment(scope, funcVar, envVar)
    scope:addReferenceToHigherScope(self.scope, self.setfenvVar);
    local bodyScope = Scope:new(scope);
    bodyScope:addReferenceToHigherScope(self.scope, self.setfenvVar);
    bodyScope:addReferenceToHigherScope(scope, funcVar);
    bodyScope:addReferenceToHigherScope(scope, envVar);
    return Ast.IfStatement(Ast.VariableExpression(self.scope, self.setfenvVar), Ast.Block({
        Ast.FunctionCallStatement(Ast.VariableExpression(self.scope, self.setfenvVar), {
            Ast.VariableExpression(scope, funcVar),
            Ast.VariableExpression(scope, envVar),
        }),
    }, bodyScope), {});
end

function Compiler:getCreateClosureVar(argCount)
    if not self.createClosureVars[argCount] then
        local var = Ast.AssignmentVariable(self.scope, self.scope:addVariable());
        local createClosureScope = Scope:new(self.scope);
        local createClosureSubScope = Scope:new(createClosureScope);

        local createClosurePosArg = createClosureScope:addVariable();
        local createClosureUpvalsArg = createClosureScope:addVariable();
        local createClosureEnvArg = createClosureScope:addVariable();
        local createClosureProxyObject = createClosureScope:addVariable();
        local createClosureFuncVar = createClosureScope:addVariable();

        createClosureSubScope:addReferenceToHigherScope(self.scope, self.containerFuncVar);
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosurePosArg)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureUpvalsArg, 1)
        createClosureScope:addReferenceToHigherScope(self.scope, self.upvaluesProxyFunctionVar)
        createClosureSubScope:addReferenceToHigherScope(createClosureScope, createClosureProxyObject);

        local  argsTb, argsTb2 = {}, {};
        for i = 1, argCount do
            local arg = createClosureSubScope:addVariable()
            argsTb[i] = Ast.VariableExpression(createClosureSubScope, arg);
            argsTb2[i] = Ast.TableEntry(Ast.VariableExpression(createClosureSubScope, arg));
        end
        table.insert(argsTb2, Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.NumberExpression(argCount)));

        local val = Ast.FunctionLiteralExpression({
            Ast.VariableExpression(createClosureScope, createClosurePosArg),
            Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
            Ast.VariableExpression(createClosureScope, createClosureEnvArg),
        }, Ast.Block({
                Ast.LocalVariableDeclaration(createClosureScope, {
                    createClosureProxyObject
                }, {
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.upvaluesProxyFunctionVar), {
                        Ast.VariableExpression(createClosureScope, createClosureUpvalsArg)
                    })
                }),
                Ast.LocalVariableDeclaration(createClosureScope, {createClosureFuncVar},{
                    Ast.FunctionLiteralExpression(argsTb,
                    Ast.Block({
                        Ast.ReturnStatement{
                            Ast.FunctionCallExpression(Ast.VariableExpression(self.scope, self.containerFuncVar), {
                                Ast.VariableExpression(createClosureScope, createClosurePosArg),
                                Ast.TableConstructorExpression(argsTb2),
                                Ast.VariableExpression(createClosureScope, createClosureUpvalsArg),
                                Ast.VariableExpression(createClosureScope, createClosureProxyObject),
                                self:closureEnvironment(createClosureSubScope, createClosureScope, createClosureEnvArg)
                            })
                        }
                    }, createClosureSubScope)
                    );
                });
                self:inheritClosureEnvironment(createClosureScope, createClosureFuncVar, createClosureEnvArg);
                Ast.ReturnStatement{Ast.VariableExpression(createClosureScope, createClosureFuncVar)}
            }, createClosureScope)
        );
        self.createClosureVars[argCount] = {
            var = var,
            val = val,
        }
    end


    local var = self.createClosureVars[argCount].var;
    return var.scope, var.id;
end

return Compiler;

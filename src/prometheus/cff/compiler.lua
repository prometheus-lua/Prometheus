-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- compiler.lua
--
-- This Script is the main compiler module.

local Ast = require("prometheus.ast");
local analyzeBindings = require("prometheus.bindinganalysis");
local util = require("prometheus.util");
local Source = require("prometheus.source");

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
    self.currentOrigin = nil;
    analyzeBindings(ast);
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

    local getfenvVar, setfenvVar = "getfenv", "setfenv";
    local tableVar, unpackVar, envVar = "table", "unpack", "_ENV";
    local newproxyVar, setmetatableVar, getmetatableVar = "newproxy", "setmetatable", "getmetatable";
    local selectVar, tonumberVar, errorVar = "select", "tonumber", "error";
    self.envVar = Ast.LocalSymbol();
    self.getfenvVar = Ast.LocalSymbol();
    self.setfenvVar = Ast.LocalSymbol();
    self.callFunctionVar = Ast.LocalSymbol();
    self.containerFuncVar = Ast.LocalSymbol();
    self.unpackVar = Ast.LocalSymbol();
    self.packVar = Ast.LocalSymbol();
    self.unpackPackedVar = Ast.LocalSymbol();
    self.newproxyVar = Ast.LocalSymbol();
    self.setmetatableVar = Ast.LocalSymbol();
    self.getmetatableVar = Ast.LocalSymbol();
    self.selectVar = Ast.LocalSymbol();
    self.tonumberVar = Ast.LocalSymbol();
    self.errorVar = Ast.LocalSymbol();

    local argVar = Ast.LocalSymbol();


    self.posVar = Ast.LocalSymbol();
    self.argsVar = Ast.LocalSymbol();
    self.currentUpvaluesVar = Ast.LocalSymbol();
    self.detectGcCollectVar = Ast.LocalSymbol();
    self.currentEnvVar = Ast.LocalSymbol();
    self.returnVar = Ast.LocalSymbol();

    self.upvaluesTable = Ast.LocalSymbol();
    self.upvaluesReferenceCountsTable = Ast.LocalSymbol();
    self.allocUpvalFunction = Ast.LocalSymbol();
    self.currentUpvalId = Ast.LocalSymbol();

    self.upvaluesProxyFunctionVar = Ast.LocalSymbol();
    self.upvaluesGcFunctionVar = Ast.LocalSymbol();
    self.freeUpvalueFunc = Ast.LocalSymbol();

    self.createClosureVars = {};
    self.createVarargClosureVar = Ast.LocalSymbol();

    local createClosurePosArg = Ast.LocalSymbol();
    local createClosureUpvalsArg = Ast.LocalSymbol();
    local createClosureEnvArg = Ast.LocalSymbol();
    local createClosureProxyObject = Ast.LocalSymbol();
    local createClosureFuncVar = Ast.LocalSymbol();

    local upvalEntries = {};
    local upvalueIds = {};
    self.getUpvalueId = function(self, scope, id)
        local expression;
        local scopeFuncDepth = self.scopeFunctionDepths[scope];
        if(scopeFuncDepth == 0) then
            if upvalueIds[id] then
                return upvalueIds[id];
            end
            expression = Ast.FunctionCallExpression(Ast.VariableExpression(self.allocUpvalFunction), {});
        else
            require("logger"):error("Unresolved Upvalue, this error should not occur!");
        end
        table.insert(upvalEntries, Ast.TableEntry(expression));
        local uid = #upvalEntries;
        upvalueIds[id] = uid;
        return uid;
    end


    self:compileTopNode(ast);

    -- VM value lists carry an explicit count: table length loses trailing nils.


    local unpackValuesVar = Ast.LocalSymbol();

    -- Keep query handling shared: a per-call closure would capture the frame's
    -- environment and delay its collection when another Cff pass wraps it.
    -- Ordinary functions receive exactly their original arguments via a tail call.

    local callFuncVar, callEnvVar = Ast.LocalSymbol(), Ast.LocalSymbol();

    local levelVar = Ast.LocalSymbol();

    local functionNodeAssignments = {
        {
            var = Ast.AssignmentVariable(self.callFunctionVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(callFuncVar),
                Ast.VariableExpression(callEnvVar),
                Ast.VarargExpression(),
            }, Ast.Block({
                Ast.IfStatement(Ast.AndExpression(
                    Ast.VariableExpression(self.getfenvVar),
                    Ast.EqualsExpression(Ast.VariableExpression(callFuncVar), Ast.VariableExpression(self.getfenvVar))
                ), Ast.Block({
                    Ast.LocalVariableDeclaration({levelVar}, {Ast.VarargExpression()}),
                    Ast.IfStatement(Ast.OrExpression(
                        Ast.EqualsExpression(Ast.VariableExpression(levelVar), Ast.NilExpression()),
                        Ast.EqualsExpression(Ast.VariableExpression(levelVar), Ast.NumberExpression(1))
                    ), Ast.Block({Ast.ReturnStatement{Ast.VariableExpression(callEnvVar)}}), {}),
                }), {}),
                Ast.ReturnStatement{Ast.FunctionCallExpression(Ast.VariableExpression(callFuncVar), {Ast.VarargExpression()})},
            })),
        },
        {
            var = Ast.AssignmentVariable(self.packVar),
            val = Ast.FunctionLiteralExpression({Ast.VarargExpression()}, Ast.Block({
                Ast.ReturnStatement{Ast.TableConstructorExpression({
                    Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.FunctionCallExpression(
                        Ast.VariableExpression(self.selectVar),
                        {Ast.StringExpression("#"), Ast.VarargExpression()})),
                    Ast.TableEntry(Ast.VarargExpression()),
                })},
            })),
        }, {
            var = Ast.AssignmentVariable(self.unpackPackedVar),
            val = Ast.FunctionLiteralExpression({Ast.VariableExpression(unpackValuesVar)}, Ast.Block({
                Ast.ReturnStatement{Ast.FunctionCallExpression(Ast.VariableExpression(self.unpackVar), {
                    Ast.VariableExpression(unpackValuesVar),
                    Ast.NumberExpression(1),
                    Ast.IndexExpression(Ast.VariableExpression(unpackValuesVar), Ast.StringExpression("n")),
                })},
            })),
        },
        {
            var = Ast.AssignmentVariable(self.containerFuncVar),
            val = Ast.FunctionLiteralExpression({
                Ast.VariableExpression(self.posVar),
                Ast.VariableExpression(self.argsVar),
                Ast.VariableExpression(self.currentUpvaluesVar),
                Ast.VariableExpression(self.detectGcCollectVar),
                Ast.VariableExpression(self.currentEnvVar)
            }, self:emitContainerFuncBody());
        }, {
            var = Ast.AssignmentVariable(self.createVarargClosureVar),
            val = Ast.FunctionLiteralExpression({
                    Ast.VariableExpression(createClosurePosArg),
                    Ast.VariableExpression(createClosureUpvalsArg),
                    Ast.VariableExpression(createClosureEnvArg),
                },
                Ast.Block({
                    Ast.LocalVariableDeclaration({
                        createClosureProxyObject
                    }, {
                        Ast.FunctionCallExpression(Ast.VariableExpression(self.upvaluesProxyFunctionVar), {
                            Ast.VariableExpression(createClosureUpvalsArg)
                        })
                    }),
                    Ast.LocalVariableDeclaration({createClosureFuncVar},{
                        Ast.FunctionLiteralExpression({
                            Ast.VarargExpression();
                        },
                        Ast.Block({
                            Ast.ReturnStatement{
                                Ast.FunctionCallExpression(Ast.VariableExpression(self.containerFuncVar), {
                                    Ast.VariableExpression(createClosurePosArg),
                                    self:pack({Ast.VarargExpression()}),
                                    Ast.VariableExpression(createClosureUpvalsArg),
                                    Ast.VariableExpression(createClosureProxyObject),
                                    self:closureEnvironment(createClosureEnvArg)
                                })
                            }
                        })
                        );
                    });
                    self:inheritClosureEnvironment(createClosureFuncVar, createClosureEnvArg);
                    Ast.ReturnStatement{Ast.VariableExpression(createClosureFuncVar)};
                })
            );
        }, {
            var = Ast.AssignmentVariable(self.upvaluesTable),
            val = Ast.TableConstructorExpression({}),
        }, {
            var = Ast.AssignmentVariable(self.upvaluesReferenceCountsTable),
            val = Ast.TableConstructorExpression({}),
        }, {
            var = Ast.AssignmentVariable(self.allocUpvalFunction),
            val = self:createAllocUpvalFunction(),
        }, {
            var = Ast.AssignmentVariable(self.currentUpvalId),
            val = Ast.NumberExpression(0),
        }, {
            var = Ast.AssignmentVariable(self.upvaluesProxyFunctionVar),
            val = self:createUpvaluesProxyFunc(),
        }, {
            var = Ast.AssignmentVariable(self.upvaluesGcFunctionVar),
            val = self:createUpvaluesGcFunc(),
        }, {
            var = Ast.AssignmentVariable(self.freeUpvalueFunc),
            val = self:createFreeUpvalueFunc(),
        },
    }

    local tbl = {
        Ast.VariableExpression(self.callFunctionVar),
        Ast.VariableExpression(self.packVar),
        Ast.VariableExpression(self.unpackPackedVar),
        Ast.VariableExpression(self.containerFuncVar),
        Ast.VariableExpression(self.createVarargClosureVar),
        Ast.VariableExpression(self.upvaluesTable),
        Ast.VariableExpression(self.upvaluesReferenceCountsTable),
        Ast.VariableExpression(self.allocUpvalFunction),
        Ast.VariableExpression(self.currentUpvalId),
        Ast.VariableExpression(self.upvaluesProxyFunctionVar),
        Ast.VariableExpression(self.upvaluesGcFunctionVar),
        Ast.VariableExpression(self.freeUpvalueFunc),
    };
    for i, entry in pairs(self.createClosureVars) do
        table.insert(functionNodeAssignments, entry);
        table.insert(tbl, Ast.VariableExpression(entry.symbol));
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
        Ast.VariableExpression(self.envVar),
        Ast.VariableExpression(self.unpackVar),
        Ast.VariableExpression(self.newproxyVar),
        Ast.VariableExpression(self.setmetatableVar),
        Ast.VariableExpression(self.getmetatableVar),
        Ast.VariableExpression(self.selectVar),
        Ast.VariableExpression(argVar),
        Ast.VariableExpression(self.tonumberVar),
        Ast.VariableExpression(self.errorVar),
        Ast.VariableExpression(self.getfenvVar),
        Ast.VariableExpression(self.setfenvVar),
    }

    local astItems = {
        Ast.OrExpression(Ast.AndExpression(Ast.GlobalVariableExpression(getfenvVar), Ast.FunctionCallExpression(Ast.GlobalVariableExpression(getfenvVar), {})), Ast.GlobalVariableExpression(envVar));
        Ast.OrExpression(Ast.GlobalVariableExpression(unpackVar), Ast.IndexExpression(Ast.GlobalVariableExpression(tableVar), Ast.StringExpression("unpack")));
        Ast.GlobalVariableExpression(newproxyVar);
        Ast.GlobalVariableExpression(setmetatableVar);
        Ast.GlobalVariableExpression(getmetatableVar);
        Ast.GlobalVariableExpression(selectVar);
        Ast.TableConstructorExpression({
            Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.FunctionCallExpression(
                Ast.GlobalVariableExpression(selectVar), {Ast.StringExpression("#"), Ast.VarargExpression()})),
            Ast.TableEntry(Ast.VarargExpression());
        });
        Ast.GlobalVariableExpression(tonumberVar);
        Ast.GlobalVariableExpression(errorVar);
        Ast.GlobalVariableExpression(getfenvVar);
        Ast.GlobalVariableExpression(setfenvVar);
    }

    local functionNode = Ast.FunctionLiteralExpression({
      items[ids[1]], items[ids[2]], items[ids[3]], items[ids[4]],
      items[ids[5]], items[ids[6]], items[ids[7]], items[ids[8]], items[ids[9]],
      items[ids[10]], items[ids[11]],
      unpack(util.shuffle(tbl))
    }, Ast.Block({
        Ast.AssignmentStatement(assignmentStatLhs, assignmentStatRhs);
        Ast.ReturnStatement{
            Ast.FunctionCallExpression(Ast.FunctionCallExpression(Ast.VariableExpression(self.createVarargClosureVar), {
                    Ast.NumberExpression(self.startBlockId);
                    Ast.TableConstructorExpression(upvalEntries);
                    Ast.VariableExpression(self.envVar);
                }), {Ast.FunctionCallExpression(self:unpack(), {Ast.VariableExpression(argVar)})});
        }
    }));

    return Source.fill(Ast.TopNode(Ast.Block({
        Ast.ReturnStatement{Ast.FunctionCallExpression(functionNode, {
            astItems[ids[1]], astItems[ids[2]], astItems[ids[3]], astItems[ids[4]],
            astItems[ids[5]], astItems[ids[6]], astItems[ids[7]], astItems[ids[8]], astItems[ids[9]],
            astItems[ids[10]], astItems[ids[11]],
        })};
    })), Source.generated('Cff'));
end

-- Each wrapper reads its own environment at entry, before tail-calling the VM.
-- The VM keeps this table in its call frame so recursion and yields are isolated.
function Compiler:closureEnvironment(inheritedVar)
    return Ast.OrExpression(Ast.AndExpression(
        Ast.VariableExpression(self.getfenvVar),
        Ast.FunctionCallExpression(Ast.VariableExpression(self.getfenvVar), {Ast.NumberExpression(1)})
    ), Ast.VariableExpression(inheritedVar));
end

function Compiler:inheritClosureEnvironment(funcVar, envVar)

    return Ast.IfStatement(Ast.VariableExpression(self.setfenvVar), Ast.Block({
        Ast.FunctionCallStatement(Ast.VariableExpression(self.setfenvVar), {
            Ast.VariableExpression(funcVar),
            Ast.VariableExpression(envVar),
        }),
    }), {});
end

function Compiler:getCreateClosureVar(argCount)
    if not self.createClosureVars[argCount] then
        local var = Ast.LocalSymbol();


        local createClosurePosArg = Ast.LocalSymbol();
        local createClosureUpvalsArg = Ast.LocalSymbol();
        local createClosureEnvArg = Ast.LocalSymbol();
        local createClosureProxyObject = Ast.LocalSymbol();
        local createClosureFuncVar = Ast.LocalSymbol();


        local  argsTb, argsTb2 = {}, {};
        for i = 1, argCount do
            local arg = Ast.LocalSymbol()
            argsTb[i] = Ast.VariableExpression(arg);
            argsTb2[i] = Ast.TableEntry(Ast.VariableExpression(arg));
        end
        table.insert(argsTb2, Ast.KeyedTableEntry(Ast.StringExpression("n"), Ast.NumberExpression(argCount)));

        local val = Ast.FunctionLiteralExpression({
            Ast.VariableExpression(createClosurePosArg),
            Ast.VariableExpression(createClosureUpvalsArg),
            Ast.VariableExpression(createClosureEnvArg),
        }, Ast.Block({
                Ast.LocalVariableDeclaration({
                    createClosureProxyObject
                }, {
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.upvaluesProxyFunctionVar), {
                        Ast.VariableExpression(createClosureUpvalsArg)
                    })
                }),
                Ast.LocalVariableDeclaration({createClosureFuncVar},{
                    Ast.FunctionLiteralExpression(argsTb,
                    Ast.Block({
                        Ast.ReturnStatement{
                            Ast.FunctionCallExpression(Ast.VariableExpression(self.containerFuncVar), {
                                Ast.VariableExpression(createClosurePosArg),
                                Ast.TableConstructorExpression(argsTb2),
                                Ast.VariableExpression(createClosureUpvalsArg),
                                Ast.VariableExpression(createClosureProxyObject),
                                self:closureEnvironment(createClosureEnvArg)
                            })
                        }
                    })
                    );
                });
                self:inheritClosureEnvironment(createClosureFuncVar, createClosureEnvArg);
                Ast.ReturnStatement{Ast.VariableExpression(createClosureFuncVar)}
            })
        );
        self.createClosureVars[argCount] = {
            symbol = var,
            var = Ast.AssignmentVariable(var),
            val = val,
        }
    end


    local var = self.createClosureVars[argCount].symbol;
    return var;
end

return Compiler;

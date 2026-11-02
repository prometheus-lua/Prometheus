-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- upvalue.lua
--
-- This Script contains the upvalue and GC management for the compiler.

local Ast = require("prometheus.ast");
local util = require("prometheus.util");

local unpack = unpack or table.unpack;

return function(Compiler)
    function Compiler:createUpvaluesGcFunc()
        local selfVar = Ast.LocalSymbol();

        local iteratorVar = Ast.LocalSymbol();
        local valueVar = Ast.LocalSymbol();
        return Ast.FunctionLiteralExpression({Ast.VariableExpression(selfVar)}, Ast.Block({
            Ast.LocalVariableDeclaration({iteratorVar, valueVar}, {Ast.NumberExpression(1), Ast.IndexExpression(Ast.VariableExpression(selfVar), Ast.NumberExpression(1))}),
            Ast.WhileStatement(Ast.Block({
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(valueVar)),
                    Ast.AssignmentVariable(iteratorVar),
                }, {
                    Ast.SubExpression(Ast.IndexExpression(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(valueVar)), Ast.NumberExpression(1)),
                    Ast.AddExpression(unpack(util.shuffle{Ast.VariableExpression(iteratorVar), Ast.NumberExpression(1)})),
                }),
                Ast.IfStatement(Ast.EqualsExpression(unpack(util.shuffle{Ast.IndexExpression(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(valueVar)), Ast.NumberExpression(0)})), Ast.Block({
                    Ast.AssignmentStatement({
                        Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(valueVar)),
                        Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesTable), Ast.VariableExpression(valueVar)),
                    }, {
                        Ast.NilExpression(),
                        Ast.NilExpression(),
                    })
                }), {}, nil),
                Ast.AssignmentStatement({
                    Ast.AssignmentVariable(valueVar),
                }, {
                    Ast.IndexExpression(Ast.VariableExpression(selfVar), Ast.VariableExpression(iteratorVar)),
                }),
            }), Ast.VariableExpression(valueVar));
        }));
    end

    function Compiler:createFreeUpvalueFunc()
        local argVar = Ast.LocalSymbol();
        return Ast.FunctionLiteralExpression({Ast.VariableExpression(argVar)}, Ast.Block({
            Ast.AssignmentStatement({
                Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(argVar))
            }, {
                Ast.SubExpression(Ast.IndexExpression(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(argVar)), Ast.NumberExpression(1));
            }),
            Ast.IfStatement(Ast.EqualsExpression(unpack(util.shuffle{Ast.IndexExpression(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(argVar)), Ast.NumberExpression(0)})), Ast.Block({
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(argVar)),
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesTable), Ast.VariableExpression(argVar)),
                }, {
                    Ast.NilExpression(),
                    Ast.NilExpression(),
                })
            }), {}, nil)
        }))
    end

    function Compiler:createUpvaluesProxyFunc()
        local entriesVar = Ast.LocalSymbol();
        local proxyVar = Ast.LocalSymbol();
        local metatableVar = Ast.LocalSymbol();
        local forArg = Ast.LocalSymbol();

        return Ast.FunctionLiteralExpression({Ast.VariableExpression(entriesVar)}, Ast.Block({
            Ast.ForStatement(forArg, Ast.NumberExpression(1), Ast.LenExpression(Ast.VariableExpression(entriesVar)), Ast.NumberExpression(1), Ast.Block({
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.IndexExpression(Ast.VariableExpression(entriesVar), Ast.VariableExpression(forArg)))
                }, {
                    Ast.AddExpression(unpack(util.shuffle{
                        Ast.IndexExpression(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.IndexExpression(Ast.VariableExpression(entriesVar), Ast.VariableExpression(forArg))),
                        Ast.NumberExpression(1),
                    }))
                })
            }));
            Ast.IfStatement(Ast.VariableExpression(self.newproxyVar), Ast.Block({
                Ast.LocalVariableDeclaration({proxyVar}, {
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.newproxyVar), {
                        Ast.BooleanExpression(true)
                    });
                });
                Ast.LocalVariableDeclaration({metatableVar}, {
                    Ast.FunctionCallExpression(Ast.VariableExpression(self.getmetatableVar), {
                        Ast.VariableExpression(proxyVar);
                    });
                });
                Ast.AssignmentStatement({
                    Ast.AssignmentIndexing(Ast.VariableExpression(metatableVar), Ast.StringExpression("__index")),
                    Ast.AssignmentIndexing(Ast.VariableExpression(metatableVar), Ast.StringExpression("__gc")),
                    Ast.AssignmentIndexing(Ast.VariableExpression(metatableVar), Ast.StringExpression("__len")),
                }, {
                    Ast.VariableExpression(entriesVar),
                    Ast.VariableExpression(self.upvaluesGcFunctionVar),
                    Ast.FunctionLiteralExpression({}, Ast.Block({
                        Ast.ReturnStatement({Ast.NumberExpression(self.upvalsProxyLenReturn)})
                    }));
                });
                Ast.ReturnStatement({
                    Ast.VariableExpression(proxyVar)
                })
            }), {}, Ast.Block({
                Ast.ReturnStatement({Ast.FunctionCallExpression(Ast.VariableExpression(self.setmetatableVar), {
                    Ast.TableConstructorExpression({}),
                    Ast.TableConstructorExpression({
                        Ast.KeyedTableEntry(Ast.StringExpression("__gc"), Ast.VariableExpression(self.upvaluesGcFunctionVar)),
                        Ast.KeyedTableEntry(Ast.StringExpression("__index"), Ast.VariableExpression(entriesVar)),
                        Ast.KeyedTableEntry(Ast.StringExpression("__len"), Ast.FunctionLiteralExpression({}, Ast.Block({
                            Ast.ReturnStatement({Ast.NumberExpression(self.upvalsProxyLenReturn)})
                        }))),
                    })
                })})
            }));
        }));
    end

    function Compiler:createAllocUpvalFunction()
        return Ast.FunctionLiteralExpression({}, Ast.Block({
            Ast.AssignmentStatement({
                    Ast.AssignmentVariable(self.currentUpvalId),
                },{
                    Ast.AddExpression(unpack(util.shuffle({
                        Ast.VariableExpression(self.currentUpvalId),
                        Ast.NumberExpression(1),
                    }))),
                }
            ),
            Ast.AssignmentStatement({
                Ast.AssignmentIndexing(Ast.VariableExpression(self.upvaluesReferenceCountsTable), Ast.VariableExpression(self.currentUpvalId)),
            }, {
                Ast.NumberExpression(1),
            }),
            Ast.ReturnStatement({
                Ast.VariableExpression(self.currentUpvalId),
            })
        }));
    end
end


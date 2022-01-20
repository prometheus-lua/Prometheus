local Compiler = {};

local IR = require("prometheus.compiler_secure.ir");
local Bytecode = require("prometheus.compiler_secure.bytecode");
local Ast = require("prometheus.ast");
local logger = require("logger");
local AstKind = Ast.AstKind;


function Compiler:new()
    local compiler = {

    };

    setmetatable(compiler, self);
    self.__index = self;

    return compiler;
end

function Compiler:compile(ast)
    self.ir = IR:new();
    self.scopeStack = {};

    self:compileTopNode(ast);
    self.ir:optimize();

    local vmSettings = Bytecode:generateVmSettings(self.ir);
    local newAst = Bytecode:generateVm(vmSettings, self.ir);
    
    -- Print IR In readable Format for debugging
    logger:debug(self.ir:toString());

    self.ir = nil;
    self.scopeStack = {};
    self.currentScope = nil;
    return newAst;
end

function Compiler:compileTopNode(topNode)
    local ir = self.ir;
    local startNop = IR:NOP();
    -- Create Main Function
    local mainFunc = ir:createFunction(startNop);
    assert(mainFunc == 1, "The main Function was not the first Function created. This is probably a Compiler bug!");
    ir:instruction(startNop);

    self.currentScope = topNode.body.scope;
    self:compileBlock(topNode.body, false);
    self.currentScope = nil;

    -- Finalizing Return
    ir:instruction(IR:RET3()); -- No Return Value

    -- Compile All other Functions
    self:compileNextCuedFunction();

    -- Compilation Done
    return true;
end

local functionCue = {};
function Compiler:encueFunction(func, currentScope, scopeStack)
    assert(func and func.body);
    local scopeStackCopy = {};
    for i, scope in pairs(scopeStack) do
        scopeStackCopy[i] = scope;
    end
    local start = IR:NOP();
    table.insert(functionCue, {
        func = func,
        start = start,
        currentScope = currentScope,
        scopeStack = scopeStackCopy,
    });
    return self.ir:createFunction(start);
end

function Compiler:compileNextCuedFunction()   
    -- Technnically it is a Function Stack
    local data = table.remove(functionCue);
    if not data then
        return false;
    end
    local ir = self.ir;
    local func = data.func;

    self.scopeStack = data.scopeStack;
    self.currentScope = data.currentScope;

    ir:instruction(data.start);

    table.insert(self.scopeStack, self.currentScope);
    self.currentScope = func.body.scope;

    for i, arg in ipairs(func.args) do
        if(arg.kind == AstKind.VarargExpression) then
            assert(i == #func.args, "Vararg must be the Last Argument. Something went Wrong!");
            self.varargOffset = i - 1;
        else
            ir:instruction(IR:LOADARG(i));
            ir:instruction(IR:SETLOCAL(arg.id, 0));
        end
    end
   

    self:compileBlock(func.body, false);
    table.remove(self.scopeStack);
    self.scopeStack = nil;
    self.currentScope = nil;
    self.varargOffset = nil;

    -- Finalizing Return
    ir:instruction(IR:RET3()); -- No Return Value

    -- Compile next Function
    self:compileNextCuedFunction();
    return true;
end

function Compiler:compileBlock(block, doScope)
    if #block.statements < 1 then return true end;
    local ir = self.ir;
    -- Push New Scope for Block
    if doScope then
        table.insert(self.scopeStack, self.currentScope);
        self.currentScope = block.scope;
        ir:instruction(IR:PUSHSCOPE());
    end

    for i, statement in ipairs(block.statements) do
        self:compileStatement(statement);
    end

    -- Pop The Scope after the block
    if doScope then
        ir:instruction(IR:POPSCOPE());
        self.currentScope = table.remove(self.scopeStack);
    end
    
    return true;
end

function Compiler:compileStatement(statement)
    local ir = self.ir;
    if(statement.kind == AstKind.DoStatement) then
        -- Do Statement is Really Simple
        self:compileBlock(statement.body, true);
        return true;
    end

    if(statement.kind == AstKind.ReturnStatement) then
        -- Return Statement
        local len = #statement.args;

        if len < 1 then
            ir:instruction(IR:RET3()); -- No Return Values
            return true;
        end

        for i, arg in ipairs(statement.args) do
            self:compileExpression(arg, i >= len);
        end

        -- Pack all values on the stack into one Table and then return using that table;
        ir:instruction(IR:PACK());
        ir:instruction(IR:RET());
        return true;
    end

    if(statement.kind == AstKind.LocalFunctionDeclaration) then
        local id = self:encueFunction(statement, self.currentScope, self.scopeStack);
        ir:instruction(IR:FUNC(id));
        ir:instruction(IR:SETLOCAL(statement.id, 0));
        return true;
    end

    if(statement.kind == AstKind.FunctionDeclaration) then
        local id = self:encueFunction(statement, self.currentScope, self.scopeStack);
        ir:instruction(IR:FUNC(id));
        if(#statement.indices == 0) then
            if(statement.baseScope.isGlobal) then
                ir:instruction(IR:LOADCONST(ir:constant(statement.baseScope:getVariableName(statement.id))));
                local id = self:encueFunction(statement, self.currentScope, self.scopeStack);
                ir:instruction(IR:FUNC(id));
                ir:instruction(IR:SETGLOBAL());
            else
                local id = self:encueFunction(statement, self.currentScope, self.scopeStack);
                ir:instruction(IR:FUNC(id));
                local levelDiff = self.currentScope.level - statement.baseScope.level;
                ir:instruction(IR:SETLOCAL(statement.id, levelDiff));
            end
        else
            if(statement.baseScope.isGlobal) then
                ir:instruction(IR:LOADCONST(ir:constant(statement.baseScope:getVariableName(statement.id))));
                ir:instruction(IR:GETGLOBAL());
            else
                local levelDiff = self.currentScope.level - statement.baseScope.level;
                ir:instruction(IR:GETLOCAL(statement.id, levelDiff));
            end

            local len = #statement.indices;
            for i, index in ipairs(statement.indices) do
                if i == len then
                    ir:instruction(IR:LOADCONST(ir:constant(index)));
                    local id = self:encueFunction(statement, self.currentScope, self.scopeStack);
                    ir:instruction(IR:FUNC(id));
                    ir:instruction(IR:SETTABLE());
                    ir:instruction(IR:DROP());
                else
                    ir:instruction(IR:LOADCONST(ir:constant(index)));
                    ir:instruction(IR:GETTABLE2());
                end
            end
        end
        return true;
    end

    if(statement.kind == AstKind.FunctionCallStatement) then
        self:compileExpression(statement.base, false);
        ir:instruction(IR:PUSHTEMPSTACK());
        local len = #statement.args;
        for i, arg in ipairs(statement.args) do
            self:compileExpression(arg, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());
        ir:instruction(IR:CALL());
        ir:instruction(IR:CLEARSTACK());
        return true;
    end

    if(statement.kind == AstKind.PassSelfFunctionCallStatement) then
        self:compileExpression(statement.base, false);
        ir:instruction(IR:PUSHTEMPSTACK2());
        local len = #statement.args;
        for i, arg in ipairs(statement.args) do
            self:compileExpression(arg, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:LOADCONST(ir:constant(statement.passSelfFunctionName)));
        ir:instruction(IR:GETTABLE());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:DROP());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:CALL());
        ir:instruction(IR:CLEARSTACK());
        return true;
    end

    if(statement.kind == AstKind.IfStatement) then
        local nextJumpToNop = IR:NOP();
        local endNop = IR:NOP();
        self:compileExpression(statement.condition, false);
        ir:instruction(IR:NOT());
        ir:instruction(IR:JMPC(nextJumpToNop));
        self:compileBlock(statement.body, true);
        ir:instruction(IR:JMP(endNop));

        for i, eif in ipairs(statement.elseifs) do
            ir:instruction(nextJumpToNop);
            nextJumpToNop = IR:NOP();
            self:compileExpression(eif.condition, false);
            ir:instruction(IR:NOT());
            ir:instruction(IR:JMPC(nextJumpToNop));
            self:compileBlock(eif.body, true);
            ir:instruction(IR:JMP(endNop));
        end


        ir:instruction(nextJumpToNop);
        if(statement.elsebody) then
            self:compileBlock(statement.elsebody, true);
        end
        ir:instruction(endNop);
        return true;
    end

    if(statement.kind == AstKind.WhileStatement) then
        local startNop = IR:NOP();
        statement.__startnop = startNop;
        local endNop = IR:NOP();
        statement.__endnop = endNop;

        ir:instruction(startNop);
        self:compileExpression(statement.condition, false);
        ir:instruction(IR:NOT());
        ir:instruction(IR:JMPC(endNop));

        self:compileBlock(statement.body, true);

        ir:instruction(IR:JMP(startNop));
        ir:instruction(endNop);
        return true;
    end

    if(statement.kind == AstKind.RepeatStatement) then
        local startNop = IR:NOP();
        statement.__startnop = startNop;
        local endNop = IR:NOP();
        statement.__endnop = endNop;

        ir:instruction(startNop);

        table.insert(self.scopeStack, self.currentScope);
        self.currentScope = statement.body.scope;

        ir:instruction(IR:PUSHSCOPE());
        self:compileBlock(statement.body, false);
        self:compileExpression(statement.condition, false);
        ir:instruction(IR:POPSCOPE());
        ir:instruction(IR:JMPC(endNop));
        ir:instruction(IR:JMP(startNop));
        ir:instruction(endNop);
        self.currentScope = table.remove(self.scopeStack);
        return true;
    end

    if(statement.kind == AstKind.BreakStatement) then
        local levelDiff =  statement.scope.level - statement.loop.parentScope.level;
        assert(levelDiff >= 0);
        for i = 1, levelDiff do
            ir:instruction(IR:POPSCOPE());
        end
        ir:instruction(IR:JMP(statement.loop.__endnop));
        return true;
    end

    if(statement.kind == AstKind.ContinueStatement) then
        local levelDiff = statement.scope.level - statement.loop.parentScope.level;
        assert(levelDiff >= 0);
        for i = 1, levelDiff do
            ir:instruction(IR:POPSCOPE());
        end
        ir:instruction(IR:JMP(statement.loop.__startnop));
        return true;
    end

    if(statement.kind == AstKind.LocalVariableDeclaration) then
        local maxi = 0;
        if(#statement.expressions < 1) then
            return true;
        end
        ir:instruction(IR:PUSHTEMPSTACK());
        local len = #statement.expressions;
        for i, expression in ipairs(statement.expressions) do
            self:compileExpression(expression, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());

        for i, id in ipairs(statement.ids) do
            ir:instruction(IR:LOADCONST(ir:constant(i)));
            ir:instruction(IR:ASSIGNLOCAL(id, 0));
        end

        ir:instruction(IR:DROP());
        return true;
    end

    if(statement.kind == AstKind.ForStatement) then
        self:compileExpression(statement.initialValue, false);
        self:compileExpression(statement.finalValue, false);
        self:compileExpression(statement.incrementBy or Ast.NumberExpression(1), false);
        ir:instruction(IR:FORPREP());
        local fskip = IR:FORSKIP(statement.id);
        ir:instruction(fskip);
        local endNop = IR:NOP();
        ir:instruction(IR:JMP(endNop));
        ir:instruction(IR:PUSHTEMPSTACK());

        statement.__endnop = endNop;
        statement.__startnop = fskip;

        table.insert(self.scopeStack, self.currentScope);
        self.currentScope = statement.body.scope;

        self:compileBlock(statement.body, false);

        ir:instruction(IR:POPTEMPSTACK2());
        ir:instruction(IR:POPSCOPE());
        ir:instruction(IR:JMP(fskip));
        ir:instruction(endNop);
        ir:instruction(IR:CLEARSTACK());

        self.currentScope = table.remove(self.scopeStack);
        return true;
    end

    if(statement.kind == AstKind.ForInStatement) then
        ir:instruction(IR:PUSHTEMPSTACK());
        local len = #statement.expressions;
        for i, expression in ipairs(statement.expressions) do
            self:compileExpression(expression, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());

        local fskip = IR:FORINSKIP();
        local endNop   = IR:NOP();

        statement.__endnop = endNop;
        statement.__endnop = endNop;

        ir:instruction(fskip);
        ir:instruction(IR:JMP(endNop));

        table.insert(self.scopeStack, self.currentScope);
        self.currentScope = statement.body.scope;

        for i, id in ipairs(statement.ids) do
            ir:instruction(IR:LOADCONST(ir:constant(i)));
            ir:instruction(IR:GETTABLE());
            ir:instruction(IR:SETLOCAL(id, 0));
        end
        ir:instruction(IR:DROP());

        ir:instruction(IR:PUSHTEMPSTACK());
    
        self:compileBlock(statement.body, false);

        ir:instruction(IR:POPTEMPSTACK2());
        ir:instruction(IR:POPSCOPE());
        ir:instruction(IR:JMP(fskip));
        ir:instruction(endNop);
        ir:instruction(IR:CLEARSTACK());

        self.currentScope = table.remove(self.scopeStack);
        return true;
    end

    if(statement.kind == AstKind.AssignmentStatement) then
        if(#statement.lhs == 1) then
            local assignment = statement.lhs[1];
            if(assignment.kind == AstKind.AssignmentVariable) then
                -- Single Variable Assignment can be optimized
                if(assignment.scope.isGlobal) then
                    ir:instruction(IR:LOADCONST(ir:constant(assignment.scope:getVariableName(assignment.id))));
                    self:compileExpression(statement.rhs[1], false);
                    ir:instruction(IR:SETGLOBAL());
                else
                    self:compileExpression(statement.rhs[1], false);
                    local levelDiff = self.currentScope.level - assignment.scope.level;
                    ir:instruction(IR:SETLOCAL(assignment.id, levelDiff));
                end
            else
                -- Single Table Assignment can be optimized
                self:compileExpression(assignment.base, false);
                self:compileExpression(assignment.index, false);
                self:compileExpression(statement.rhs[1], false);
                ir:instruction(IR:SETTABLE());
            end

            -- Drop the remaining rhs expressions. This will be optimized out if the rhs expressions are not call Expressions
            for i = 2, #statement.rhs, 1 do
                self:compileExpression(statement.rhs[i], false);
                ir:instruction(IR:DROP());
            end

            return true;
        end

        local llen = 0;
        local offsets = {};
        for i, primary in ipairs(statement.lhs) do
            if(primary.kind == AstKind.AssignmentIndexing) then
                offsets[primary] = llen;
                llen = llen + 2;
                self:compileExpression(primary.base);
                self:compileExpression(primary.index);
            end
        end

        ir:instruction(IR:PUSHTEMPSTACK());
        local len = #statement.rhs;
        for i, expression in ipairs(statement.rhs) do
            self:compileExpression(expression, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());

        for i, primary in ipairs(statement.lhs) do
            if(primary.kind == AstKind.AssignmentVariable) then
                -- Variable Assignment
                if(primary.scope.isGlobal) then
                    ir:instruction(IR:LOADCONST(ir:constant(primary.scope:getVariableName(primary.id))));
                    ir:instruction(IR:ASSIGNGLOBAL(i));
                else
                    ir:instruction(IR:LOADCONST(ir:constant(i)));
                    local levelDiff = self.currentScope.level - primary.scope.level;
                    ir:instruction(IR:ASSIGNLOCAL(primary.id, levelDiff));
                end
            else
                -- Table Assignment
                ir:instruction(IR:ASSIGNTABLE(i,llen - offsets[primary]));
            end
        end

        ir:instruction(IR:CLEARSTACK());
        return true;
    end

    error(string.format("%s is not yet implemented", statement.kind))
end

function Compiler:compileExpression(expression, yieldMultiple)
    local ir = self.ir;
    if(expression.kind == AstKind.StringExpression) then
        local str = ir:constant(expression.value);
        ir:instruction(IR:LOADCONST(str));
        return true;
    end

    if(expression.kind == AstKind.NumberExpression) then
        local num = ir:constant(expression.value);
        ir:instruction(IR:LOADCONST(num));
        return true;
    end

    if(expression.kind == AstKind.BooleanExpression) then
        if(expression.value) then
            ir:instruction(IR:LOADTRUE());
        else
            ir:instruction(IR:LOADFALSE());
        end
        return true;
    end

    if(expression.kind == AstKind.NilExpression) then
        ir:instruction(IR:LOADNIL());
        return true;
    end

    if(expression.kind == AstKind.VariableExpression) then
        if(expression.scope.isGlobal) then
            -- Global Variable
            local name = expression.scope:getVariableName(expression.id);
            ir:instruction(IR:LOADCONST(ir:constant(name)));
            ir:instruction(IR:GETGLOBAL());
        else
            local levelDiff = self.currentScope.level - expression.scope.level;
            ir:instruction(IR:GETLOCAL(expression.id, levelDiff));
        end
        return true;
    end

    if(expression.kind == AstKind.FunctionCallExpression) then
        self:compileExpression(expression.base, false);
        ir:instruction(IR:PUSHTEMPSTACK());
        local len = #expression.args;
        for i, arg in ipairs(expression.args) do
            self:compileExpression(arg, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());
        ir:instruction(IR:CALL());
        if(yieldMultiple) then
            ir:instruction(IR:UNPACK());
        else
            ir:instruction(IR:UNPACKFIRST());
        end
        return true;
    end

    if(expression.kind == AstKind.VarargExpression) then
        if(yieldMultiple) then
            if(not self.varargOffset) then
                logger:error("Vararg Literals are only valid inside of Vararg Functions!")
            end
            ir:instruction(IR:LOADARGS(self.varargOffset));
            ir:instruction(IR:UNPACK());
        else
            ir:instruction(IR:LOADARG(1));
        end
        return true;
    end

    if(expression.kind == AstKind.PassSelfFunctionCallExpression) then
        self:compileExpression(expression.base, false);
        ir:instruction(IR:PUSHTEMPSTACK2());
        local len = #expression.args;
        for i, arg in ipairs(expression.args) do
            self:compileExpression(arg, i >= len);
        end
        ir:instruction(IR:PACK());
        ir:instruction(IR:POPTEMPSTACK());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:LOADCONST(ir:constant(expression.passSelfFunctionName)));
        ir:instruction(IR:GETTABLE());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:DROP());
        ir:instruction(IR:SWAP());
        ir:instruction(IR:CALL());
        if(yieldMultiple) then
            ir:instruction(IR:UNPACK());
        else
            ir:instruction(IR:UNPACKFIRST());
        end
        return true;
    end

    if(expression.kind == AstKind.IndexExpression) then
        self:compileExpression(expression.base, false);
        self:compileExpression(expression.index);
        ir:instruction(IR:GETTABLE2());
        return true;
    end

    if(expression.kind == AstKind.AddExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:ADD());
        return true;
    end

    if(expression.kind == AstKind.SubExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:SUB());
        return true;
    end

    if(expression.kind == AstKind.MulExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:MUL());
        return true;
    end

    if(expression.kind == AstKind.DivExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:DIV());
        return true;
    end

    if(expression.kind == AstKind.ModExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:MOD());
        return true;
    end

    if(expression.kind == AstKind.StrCatExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:CONCAT());
        return true;
    end

    if(expression.kind == AstKind.PowExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:POW());
        return true;
    end

    if(expression.kind == AstKind.LessThanExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:LT());
        return true;
    end

    if(expression.kind == AstKind.GreaterThanExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:GT());
        return true;
    end

    if(expression.kind == AstKind.LessThanOrEqualsExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:LET());
        return true;
    end

    if(expression.kind == AstKind.GreaterThanOrEqualsExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:GET());
        return true;
    end

    if(expression.kind == AstKind.EqualsExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:EQ());
        return true;
    end

    if(expression.kind == AstKind.NotEqualsExpression) then
        self:compileExpression(expression.lhs);
        self:compileExpression(expression.rhs);
        ir:instruction(IR:NEQ());
        return true;
    end

    if(expression.kind == AstKind.NegateExpression) then
        self:compileExpression(expression.rhs);
        ir:instruction(IR:NEG());
        return true;
    end

    if(expression.kind == AstKind.NotExpression) then
        self:compileExpression(expression.rhs);
        ir:instruction(IR:NOT());
        return true;
    end

    if(expression.kind == AstKind.OrExpression) then
        local endNop = IR:NOP();
        self:compileExpression(expression.lhs);
        ir:instruction(IR:DUP());
        ir:instruction(IR:JMPC(endNop));
        ir:instruction(IR:DROP());
        self:compileExpression(expression.rhs);
        ir:instruction(endNop);
        return true;
    end

    if(expression.kind == AstKind.AndExpression) then
        local endNop = IR:NOP();
        self:compileExpression(expression.lhs);
        ir:instruction(IR:DUP());
        ir:instruction(IR:NOT());
        ir:instruction(IR:JMPC(endNop));
        ir:instruction(IR:DROP());
        self:compileExpression(expression.rhs);
        ir:instruction(endNop);
        return true;
    end

    if(expression.kind == AstKind.LenExpression) then
        self:compileExpression(expression.rhs);
        ir:instruction(IR:LEN());
        return true;
    end

    if(expression.kind == AstKind.TableConstructorExpression) then
        -- The Implementation of Tables follows the LuaU spec, meaning that all values are evaluated AND assigned in the order in that they are written
        local arrI = 1;
        ir:instruction(IR:NEWTABLE());
        local len = #expression.entries;
        for i, entry in ipairs(expression.entries) do
            if(entry.kind == AstKind.TableEntry) then
                if(i == len) then
                    ir:instruction(IR:PUSHTEMPSTACK());
                    self:compileExpression(entry.value, true);
                    ir:instruction(IR:PACK());
                    ir:instruction(IR:POPTEMPSTACK());
                    ir:instruction(IR:SETTABLE3(arrI));
                else
                    self:compileExpression(entry.value, false);
                    ir:instruction(IR:SETTABLE2(arrI));
                    arrI = arrI + 1;
                end
            else
                self:compileExpression(entry.key, false);
                self:compileExpression(entry.value, false);
                ir:instruction(IR:SETTABLE());
            end
        end
        return true;
    end

    if(expression.kind == AstKind.FunctionLiteralExpression) then
        local id = self:encueFunction(expression, self.currentScope, self.scopeStack);
        ir:instruction(IR:FUNC(id));
        return true;
    end

    error(string.format("%s is not yet implemented", expression.kind))
end

return Compiler;
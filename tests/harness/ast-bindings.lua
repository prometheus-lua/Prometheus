local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Ast = require('prometheus.ast')
local analyze = require('prometheus.bindinganalysis')
local Parser = require('prometheus.parser')
local K = Ast.AstKind
local function parse(source) return Parser:new({LuaVersion = 'Lua51'}):parse(source) end
local function tree(statements) return Ast.TopNode(Ast.Block(statements)) end
local function rejects(ast, message)
    local ok, err = pcall(analyze, ast)
    assert(not ok and tostring(err):find(message, 1, true), tostring(err))
end
local function run(ast)
    local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1, Steps = {}})
    pipeline:renameVariables(ast)
    return assert(loadstring(pipeline:unparse(ast)))()
end

-- Binding identity does not depend on source spelling or construction scopes.
local x, y = Ast.LocalSymbol('x'), Ast.LocalSymbol('x')
local read = Ast.VariableExpression(x)
local ast = tree({
    Ast.LocalVariableDeclaration({x}, {Ast.NumberExpression(41)}),
    Ast.LocalVariableDeclaration({y}, {Ast.AddExpression(read, Ast.NumberExpression(1))}),
    Ast.ReturnStatement({Ast.VariableExpression(x), Ast.VariableExpression(y)}),
})
analyze(ast)
local plain = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1, Steps = {}}):unparse(ast)
local plainA, plainB = assert(loadstring(plain))()
assert(plainA == 41 and plainB == 42, 'Direct emission must preserve symbol identity despite name collisions')
local a, b = run(ast)
assert(a == 41 and b == 42)
assert(read.symbol == x and x ~= y)

-- Reanalysis ignores stale metadata and counts actual occurrences, not constructors.
local unused = Ast.VariableExpression(x)
local count = x.scope.referenceCounts[x.id]
analyze(ast)
assert(x.scope.referenceCounts[x.id] == count)
local inner = Ast.Block({Ast.ReturnStatement({Ast.VariableExpression(x)})})
ast.body.statements[#ast.body.statements] = Ast.DoStatement(inner)
analyze(ast)
assert(inner.scope.parentScope == ast.body.scope)
assert(inner.scope.variablesFromHigherScopes[x.scope][x.id] == 1)
assert(run(ast) == 41)

local missing = Ast.LocalSymbol('missing')
rejects(tree({Ast.ReturnStatement({Ast.VariableExpression(missing)})}), 'not accessible')
rejects(tree({Ast.ReturnStatement({Ast.VariableExpression(missing)}),
    Ast.LocalVariableDeclaration({missing}, {})}), 'not accessible')
rejects(tree({Ast.LocalVariableDeclaration({missing}, {Ast.VariableExpression(missing)})}), 'not accessible')
rejects(tree({Ast.DoStatement(Ast.Block({Ast.LocalVariableDeclaration({missing}, {})})),
    Ast.ReturnStatement({Ast.VariableExpression(missing)})}), 'not accessible')
rejects(tree({Ast.LocalVariableDeclaration({missing}, {}),
    Ast.LocalVariableDeclaration({missing}, {})}), 'multiple declarations')

-- Removed declarations and moved definitions are checked against the new tree.
local relocated = Ast.LocalSymbol('relocated')
local declaration = Ast.LocalVariableDeclaration({relocated}, {Ast.NumberExpression(23)})
local original = Ast.Block({declaration})
ast = tree({Ast.DoStatement(original)})
analyze(ast)
original.statements = {}
ast.body.statements[2] = declaration
ast.body.statements[3] = Ast.ReturnStatement({Ast.VariableExpression(relocated)})
analyze(ast)
assert(relocated.scope == ast.body.scope and run(ast) == 23)
table.remove(ast.body.statements, 2)
rejects(ast, 'not accessible')
local sharedBlock = Ast.Block({})
rejects(tree({Ast.DoStatement(sharedBlock), Ast.DoStatement(sharedBlock)}), 'multiple times')
rejects(tree({Ast.BreakStatement()}), 'outside a loop')
local invalidIndex = Ast.LocalSymbol('index')
rejects(tree({Ast.ForStatement(invalidIndex, Ast.VariableExpression(invalidIndex),
    Ast.NumberExpression(1), Ast.NumberExpression(1), Ast.Block({}))}), 'not accessible')

-- Reads, writes, and closure capture are derived from actual reference positions.
local shared = Ast.LocalSymbol('shared')
local write = Ast.AssignmentVariable(shared)
local closure = Ast.FunctionLiteralExpression({}, Ast.Block({
    Ast.AssignmentStatement({write}, {Ast.NumberExpression(42)}),
    Ast.ReturnStatement({Ast.VariableExpression(shared)}),
}))
ast = tree({Ast.LocalVariableDeclaration({shared}, {Ast.NumberExpression(0)}),
    Ast.ReturnStatement({closure})})
local info = analyze(ast)
assert(info.captured[shared] and #info.reads[shared] == 1 and #info.writes[shared] == 1)
assert(info.writes[shared][1] == write and run(ast)() == 42)

-- Global accesses have distinct kinds and never acquire local symbols.
ast = parse('result = print; return result')
assert(ast.body.statements[1].lhs[1].kind == K.AssignmentGlobalVariable)
assert(ast.body.statements[1].rhs[1].kind == K.GlobalVariableExpression)
assert(not ast.body.statements[1].rhs[1].symbol)
assert(run(tree({Ast.ReturnStatement({Ast.GlobalVariableExpression('_VERSION')})})) == _VERSION)
-- A generated local must not shadow a global used anywhere inside its scope.
assert(run(parse('local a = 1; return type(a)')) == 'number')

-- Lua declaration points, recursive functions, loop headers and repeat conditions.
for _, source in ipairs({
    'local x = 7; do local x = x; assert(x == 7) end; return 1',
    'local function f(n) if n == 0 then return 1 end return f(n - 1) end; return f(3)',
    'local i = 3; local sum = 0; for i = i, i do sum = sum + i end; return sum',
    'local t = {5}; for t, v in ipairs(t) do assert(v == 5) end; return 1',
    'repeat local x = 9 until x == 9; return 1',
    'local x = 1; return (function() return function() return x end end)()()',
}) do ast = parse(source); analyze(ast); assert(run(ast)) end

-- Symbols are also the construction API for parameters, functions, and loops.
local f, parameter = Ast.LocalSymbol('f'), Ast.LocalSymbol('parameter')
ast = tree({Ast.LocalFunctionDeclaration(f, {parameter}, Ast.Block({
    Ast.ReturnStatement({Ast.VariableExpression(parameter)}),
})), Ast.ReturnStatement({Ast.FunctionCallExpression(Ast.VariableExpression(f), {Ast.NumberExpression(17)})})})
assert(run(ast) == 17)
local index = Ast.LocalSymbol('index')
assert(run(tree({Ast.ForStatement(index, Ast.NumberExpression(1), Ast.NumberExpression(1),
    Ast.NumberExpression(1), Ast.Block({Ast.ReturnStatement({Ast.VariableExpression(index)})}))})) == 1)

-- Function assignment targets can be local bindings or distinct global nodes.
f, parameter = Ast.LocalSymbol('f'), Ast.LocalSymbol('argument')
ast = tree({Ast.LocalVariableDeclaration({f}, {}),
    Ast.FunctionDeclaration(Ast.AssignmentVariable(f), {}, {parameter}, Ast.Block({
        Ast.ReturnStatement({Ast.VariableExpression(parameter)}),
    })), Ast.ReturnStatement({Ast.FunctionCallExpression(Ast.VariableExpression(f), {Ast.NumberExpression(19)})})})
assert(run(ast) == 19)
ast = tree({Ast.FunctionDeclaration(Ast.AssignmentGlobalVariable('example'), {}, {},
    Ast.Block({Ast.ReturnStatement({Ast.NumberExpression(29)})})),
    Ast.ReturnStatement({Ast.FunctionCallExpression(Ast.GlobalVariableExpression('example'), {})})})
local output = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1, Steps = {}}):unparse(ast)
local chunk = assert(loadstring(output))
setfenv(chunk, {})
assert(chunk() == 29)
local key, value = Ast.LocalSymbol('key'), Ast.LocalSymbol('value')
ast = tree({Ast.ForInStatement({key, value}, {Ast.FunctionCallExpression(Ast.GlobalVariableExpression('ipairs'), {
    Ast.TableConstructorExpression({Ast.TableEntry(Ast.NumberExpression(31))}),
})}, Ast.Block({Ast.ReturnStatement({Ast.VariableExpression(value)})}))})
assert(run(ast) == 31)

-- Nested declarations must not capture an explicitly retained outer reference.
local outer, shadow = Ast.LocalSymbol('value'), Ast.LocalSymbol('value')
ast = tree({Ast.LocalVariableDeclaration({outer}, {Ast.NumberExpression(1)}),
    Ast.DoStatement(Ast.Block({Ast.LocalVariableDeclaration({shadow}, {Ast.NumberExpression(2)}),
        Ast.ReturnStatement({Ast.VariableExpression(outer)})}))})
plain = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1, Steps = {}}):unparse(ast)
assert(assert(loadstring(plain))() == 1)

-- Lowering a recursive local function must preserve its declaration point.
local proxy = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1,
    Steps = {{Name = 'ProxifyLocals'}}}):apply(
    'local function f(n) if n == 0 then return 1 end return f(n - 1) end return f(3)')
assert(assert(loadstring(proxy))() == 1)

print('AST binding identity, visibility, globals and reconstruction checks passed')

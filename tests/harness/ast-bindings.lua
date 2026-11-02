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

-- Compound targets are one occurrence with both a read and a write. Reading
-- the address of an indexed target does not write its table or index bindings.
for _, operator in ipairs({'+=', '-=', '*=', '/=', '%=', '^=', '..='}) do
    local initial, operand = '1', '2'
    if operator == '..=' then initial, operand = '"a"', '"b"' end
    local compound = Parser:new({LuaVersion = 'LuaU'}):parse(
        'local x=' .. initial .. '; x ' .. operator .. ' ' .. operand .. '; return x')
    local symbol = compound.body.statements[1].symbols[1]
    local target = compound.body.statements[2].lhs
    local analysis = compound.bindingAnalysis
    assert(#analysis.reads[symbol] == 2 and #analysis.writes[symbol] == 1, operator)
    assert(analysis.reads[symbol][1] == target and analysis.writes[symbol][1] == target)
    assert(#analysis.references[symbol] == 2, 'Compound access must not duplicate reference occurrences')
end
local indexed = Parser:new({LuaVersion = 'LuaU'}):parse(
    'local t={1}; local i=1; t[i] += 2; return t[i]')
for i = 1, 2 do
    local symbol = indexed.body.statements[i].symbols[1]
    assert(#indexed.bindingAnalysis.reads[symbol] == 2)
    assert(not indexed.bindingAnalysis.writes[symbol], 'Indexed updates must not write their address bindings')
end
local compoundCapture = Parser:new({LuaVersion = 'LuaU'}):parse(
    'local x=0; return function() x += 1; return x end')
local captured = compoundCapture.body.statements[1].symbols[1]
assert(compoundCapture.bindingAnalysis.captured[captured]
    and #compoundCapture.bindingAnalysis.reads[captured] == 2
    and #compoundCapture.bindingAnalysis.writes[captured] == 1)

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

-- Preferred names can be arbitrary labels. Printing must choose valid names
-- without shadowing globals or merging bindings that normalize to the same base.
local Unparser = require('prometheus.unparser')
for _, version in ipairs({'Lua51', 'LuaU'}) do
    local symbols, values, references = {}, {}, {}
    for i, preferred in ipairs({'bad-name', 'bad name', 'bad_name', '1st', '', 'end', 'continue', 'normal_name'}) do
        symbols[i], values[i] = Ast.LocalSymbol(preferred), Ast.NumberExpression(i)
        references[i] = Ast.VariableExpression(symbols[i])
    end
    references[#references + 1] = Ast.GlobalVariableExpression('bad_name')
    local constructed = tree({Ast.LocalVariableDeclaration(symbols, values), Ast.ReturnStatement(references)})
    local unparser = Unparser:new({LuaVersion = version})
    local output = unparser:unparse(constructed)
    for _, symbol in ipairs(symbols) do assert(unparser:isValidIdentifier(symbol.name)) end
    assert(symbols[#symbols].name == 'normal_name', 'Valid preferred names should be preserved')
    assert(unparser:unparse(constructed) == output, 'Name normalization must be stable across repeated printing')
    local chunk = assert(loadstring(output))
    setfenv(chunk, {bad_name = 99})
    local result = {chunk()}
    for i = 1, #symbols do assert(result[i] == i) end
    assert(result[#symbols + 1] == 99, 'Normalized locals must not capture global accesses')
end

-- Lowering a recursive local function must preserve its declaration point.
local proxy = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1,
    Steps = {{Name = 'ProxifyLocals'}}}):apply(
    'local function f(n) if n == 0 then return 1 end return f(n - 1) end return f(3)')
assert(assert(loadstring(proxy))() == 1)

-- Repeated passes must transform earlier generated declarations and uses
-- consistently, including when a caller reuses the same step instance.
local proxySources = {
    'local function f() return 1 end return f()',
    'local function f(n) if n==0 then return 1 end return f(n-1) end return f(3)',
    'local x=0; local function f() x=x+1; return x end; f(); return f()',
}
for _, seed in ipairs({1, 4, 17}) do
    for i, source in ipairs(proxySources) do
        local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = seed,
            Steps = {{Name = 'ProxifyLocals'}, {Name = 'ProxifyLocals'}}})
        local chunk = assert(loadstring(pipeline:apply(source)))
        assert(chunk() == (i == 3 and 2 or 1), 'Repeated ProxifyLocals changed function behavior')
    end
end
local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1,
    Steps = {{Name = 'ProxifyLocals'}}})
local reused, transformed = pipeline.steps[1], parse(proxySources[2])
math.randomseed(1)
for i = 1, 3 do reused:apply(transformed, pipeline) end
assert(run(transformed) == 1, 'Reusing a step instance must not retain rewrite exemptions')

-- Steps must also operate on syntax with no cached scopes or numeric slots.
local function stripMetadata(node, seen)
    if type(node) ~= 'table' or seen[node] then return end
    seen[node] = true
    for _, field in ipairs({'scope', 'id', 'ids', 'vars', 'parentScope', 'baseScope',
        'baseId', 'globalScope', 'bindingAnalysis'}) do node[field] = nil end
    for _, child in pairs(node) do stripMetadata(child, seen) end
end
for _, config in ipairs({
    {Name = 'EncryptStrings'},
    {Name = 'ConstantArray', Settings = {Threshold = 1, StringsOnly = false,
        LocalWrapperThreshold = 1, LocalWrapperCount = 2, LocalWrapperArgCount = 2}},
    {Name = 'ProxifyLocals'},
    {Name = 'SplitStrings', Settings = {CustomFunctionType = 'local', ConcatenationType = 'custom'}},
    {Name = 'SplitStrings', Settings = {CustomFunctionType = 'global', ConcatenationType = 'custom'}},
    {Name = 'SplitStrings', Settings = {CustomFunctionType = 'inline', ConcatenationType = 'custom'}},
    {Name = 'SplitStrings', Settings = {ConcatenationType = 'table'}},
    {Name = 'SplitStrings', Settings = {ConcatenationType = 'strcat'}},
    {Name = 'WrapInFunction'},
}) do
    local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1, Steps = {config}})
    local raw = parse('local function f(n) if n == 0 then return "scope free" end return f(n-1) end return f(2)')
    stripMetadata(raw, {})
    -- Force probability gates open on every Lua runtime, while retaining the
    -- regular integer RNG for generated constants and helper variants.
    local random = math.random
    math.random = function(a, b)
        if a == nil then return 0.5 end
        if b == nil then return random(a) end
        return random(a, b)
    end
    local success, transformed = pcall(pipeline.steps[1].apply, pipeline.steps[1], raw, pipeline)
    math.random = random
    assert(success, transformed)
    assert(run(transformed or raw) == 'scope free', config.Name .. ' requires legacy scope metadata')
end
-- Backend entry points must derive their own metadata as well, including the
-- bridge used when flattening an interpreter after string encryption.
local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 1,
    Steps = {{Name = 'Vmify'}, {Name = 'EncryptStrings'}, {Name = 'Cff'}}})
local raw = parse('local value = "scope free"; return value')
for _, step in ipairs(pipeline.steps) do
    stripMetadata(raw, {})
    raw = step:apply(raw, pipeline) or raw
end
assert(run(raw) == 'scope free')

local ok = pcall(Ast.VariableExpression, {})
assert(not ok, 'Legacy scope-based reference construction must be rejected')

print('AST binding identity, visibility, globals and reconstruction checks passed')

local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local Ast = require('prometheus.ast')
local visitast = require('prometheus.visitast')
local Steps = require('prometheus.steps')
local Presets = require('src.presets')
local CffCompiler = require('prometheus.cff.compiler')

local function pack(...) return {n = select('#', ...), ...} end
local function compile(source, steps, seed)
    local generated = Prometheus.Pipeline:fromConfig({
        LuaVersion = 'Lua51', Seed = seed or 1, Steps = steps,
    }):apply(source)
    return assert(loadstring(generated)), generated
end

local function countKind(root, kind)
    local count = 0
    visitast(root, function(node) if node.kind == kind then count = count + 1 end end)
    return count
end
local function controlFlowCounts(root)
    return {
        whileCount = countKind(root, Ast.AstKind.WhileStatement),
        ifCount = countKind(root, Ast.AstKind.IfStatement),
        functionCount = countKind(root, Ast.AstKind.FunctionLiteralExpression),
    }
end
local function visitExpression(expression, parentAst, visitor)
    local wrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({expression}),}, parentAst.body.scope),
        parentAst.globalScope)
    visitast(wrapper, visitor)
end
local function applyCff(step, ast, pipeline)
    local originalNew, compiler = CffCompiler.new
    CffCompiler.new = function(class, ...)
        local instance = originalNew(class, ...)
        local originalCompile = instance.compile
        instance.compile = function(self, input)
            local output = originalCompile(self, input)
            compiler = self
            return output
        end
        return instance
    end
    local ok, result = pcall(function() return step:apply(ast, pipeline) end)
    CffCompiler.new = originalNew
    if not ok then error(result) end
    return result, compiler
end

-- Cff keeps a VM runtime function and its prototype table native, while compiling
-- the surrounding helper code into the normal randomized dispatcher.
local mediumSteps = {}
for i, step in ipairs(Presets.Medium.Steps) do
    mediumSteps[i] = {Name = step.Name, Settings = step.Settings}
end
local mediumSource = [[
    local function branch(value)
        if value < 0 then return 'negative' end
        if value == 0 then return 'zero' end
        return 'positive'
    end
    return branch(...), nil, ...
]]
for _, seed in ipairs({1, 4, 17}) do
    local chunk = compile(mediumSource, mediumSteps, seed)
    local result = pack(chunk(0, nil, 9, nil))
    assert(result.n == 6 and result[1] == 'zero' and result[2] == nil
        and result[3] == 0 and result[4] == nil and result[5] == 9 and result[6] == nil,
        'Medium with active AntiTamper changed result arity or values at seed ' .. seed)
end

-- Exercise ExcludeVm directly with an annotated native function that mutates
-- both captured locals and globals, and calls a recursive helper after the
-- original chunk has returned.
local closureAst = Parser:new({LuaVersion = 'Lua51'}):parse([[
    local outsideCounter = 0
    local sharedClosure = {value = 0}
    local nativeFunction, recursiveHelper
    nativeFunction = function(delta)
        outsideCounter = outsideCounter + delta
        sharedClosure.value = sharedClosure.value + 1
        cffNativeGlobal = (cffNativeGlobal or 0) + 1
        if delta > 0 then return recursiveHelper(delta - 1) end
        return nil, outsideCounter, nil, sharedClosure.value
    end
    recursiveHelper = function(delta)
        if delta > 0 then return nativeFunction(delta - 1) end
        return nil, outsideCounter, nil, sharedClosure.value
    end
    return nativeFunction
]])
local nativeFunction, nativeTable
visitast(closureAst, function(node)
    if node.kind == Ast.AstKind.FunctionLiteralExpression and not nativeFunction then
        nativeFunction = node
    elseif node.kind == Ast.AstKind.TableConstructorExpression and not nativeTable then
        nativeTable = node
    end
end)
assert(nativeFunction and nativeTable)
closureAst.vmRuntime, closureAst.vmData = nativeFunction, nativeTable
local previousGlobal = cffNativeGlobal
cffNativeGlobal = nil
local cffAst, closureCompiler = applyCff(Steps.Cff:new({ExcludeVm = true}), closureAst)
assert(cffAst.vmRuntime and cffAst.vmData, 'Cff dropped VM annotations')
local runtimeFound, dataFound, dispatcherFound = false, false, false
visitast(cffAst, function(node)
    if node == cffAst.vmRuntime then runtimeFound = true end
    if node == cffAst.vmData then dataFound = true end
    if node.kind == Ast.AstKind.WhileStatement then dispatcherFound = true end
end)
assert(runtimeFound and dataFound, 'Cff annotations do not point into the compiled AST')
assert(dispatcherFound, 'Cff did not emit a surrounding dispatcher')
local nativeExpressionCount = 0
for _ in pairs(closureCompiler.nativeExpressions) do nativeExpressionCount = nativeExpressionCount + 1 end
assert(nativeExpressionCount == 2 and #closureCompiler.blocks > nativeExpressionCount,
    'Cff did not preserve only the annotated expressions while compiling the surrounding helper: '
        .. nativeExpressionCount .. ' native expressions, ' .. #closureCompiler.blocks .. ' blocks')

-- The default setting retains the older behavior: flattening the VM runtime
-- changes its control-flow tree instead of preserving its annotated subtree.
local defaultVmAst = Parser:new({LuaVersion = 'Lua51'}):parse(mediumSource)
defaultVmAst = Steps.Vmify:new():apply(defaultVmAst)
local defaultRuntimeCounts = controlFlowCounts(defaultVmAst.vmRuntime)
local defaultCffAst = applyCff(Steps.Cff:new({}), defaultVmAst)
local defaultFlattenedCounts = controlFlowCounts(defaultCffAst)
local changedRuntimeTree = false
for key, value in pairs(defaultRuntimeCounts) do
    if defaultFlattenedCounts[key] ~= value then changedRuntimeTree = true end
end
assert(changedRuntimeTree, 'default Cff unexpectedly preserved the VM runtime structure')

local closureChunk = assert(loadstring(Unparser:new({LuaVersion = 'Lua51'}):unparse(cffAst)))
local returned = closureChunk()
collectgarbage('collect')
collectgarbage('collect')
local result = pack(returned(3))
assert(result.n == 4 and result[1] == nil and result[2] == 4
    and result[3] == nil and result[4] == 2,
    'native closure lost captured writes, recursive helper, or trailing nils')
result = pack(returned(0))
assert(result.n == 4 and result[1] == nil and result[2] == 4
    and result[3] == nil and result[4] == 3,
    'native closure did not share mutable captured cells after returning')
assert(cffNativeGlobal == 3, 'native global writes were not preserved')
cffNativeGlobal = previousGlobal

-- Large VM prototype data must remain a separate native initializer while the
-- EncryptStrings decoder and other surrounding helpers pass through Cff.
local fields = {}
for i = 1, 1000 do fields[i] = tostring(i) end
local largeSource = 'local values={' .. table.concat(fields, ',') .. '}; return values[1],values[1000],...'
local vmSteps = {
    {Name = 'Vmify'},
    {Name = 'EncryptStrings'},
    {Name = 'Cff', Settings = {ExcludeVm = true}},
}
local large = compile(largeSource, vmSteps, 17)
result = pack(large(nil, 7, nil))
assert(result.n == 5 and result[1] == 1 and result[2] == 1000
    and result[3] == nil and result[4] == 7 and result[5] == nil,
    'large native prototype initializer changed values or vararg arity')

-- Inspect the full Medium AST before unparse: annotations still identify native
-- VM expressions, while the anti-tamper/encryption helper code is in a Cff
-- dispatcher generated around them.
local structurePipeline = Prometheus.Pipeline:fromConfig({
    LuaVersion = 'Lua51', Seed = 4, Steps = mediumSteps,
})
local structureAst = structurePipeline.parser:parse(mediumSource)
local cffAstAfterStep, beforeRuntimeCounts, mediumCompiler
for _, step in ipairs(structurePipeline.steps) do
    if step.Name == 'Cff' then
        beforeRuntimeCounts = controlFlowCounts(structureAst.vmRuntime)
        cffAstAfterStep, mediumCompiler = applyCff(step, structureAst, structurePipeline)
        structureAst = cffAstAfterStep
    else
        structureAst = step:apply(structureAst, structurePipeline) or structureAst
    end
end
assert(cffAstAfterStep.vmRuntime and cffAstAfterStep.vmData,
    'full Medium pipeline lost native VM runtime/data annotations')
assert(countKind(cffAstAfterStep, Ast.AstKind.WhileStatement) > 0
    and countKind(cffAstAfterStep, Ast.AstKind.IfStatement) > 0,
    'full Medium helpers were not emitted through the Cff dispatcher')
local mediumNativeCount = 0
for _ in pairs(mediumCompiler.nativeExpressions) do mediumNativeCount = mediumNativeCount + 1 end
assert(mediumNativeCount == 2 and #mediumCompiler.blocks > mediumNativeCount,
    'Medium helpers were not Cff compiled around the two protected VM expressions')
-- The annotation points at the native runtime expression preserved inside its
-- generated bridge. Compare that subtree directly with the input to ExcludeVm.
local afterRuntimeCounts = controlFlowCounts(cffAstAfterStep.vmRuntime)
for key, value in pairs(beforeRuntimeCounts) do
    assert(afterRuntimeCounts[key] == value,
        'ExcludeVm changed VM runtime ' .. key .. ' from ' .. value .. ' to ' .. afterRuntimeCounts[key])
end

-- Hoisting moves every runtime literal through a cache populated at startup;
-- user constants remain encrypted in prototype data instead of the hot VM loop.
local plaintext = 'prometheus_hoist_unique_plaintext_8a1f'
local payloadSource = 'local payload={message=' .. string.format('%q', plaintext)
    .. ',again=' .. string.format('%q', plaintext) .. ',nested={"hoist_second_value"}}; '
    .. 'return payload.message,payload.again,payload.nested[1],...'
local hoistedAst = Parser:new({LuaVersion = 'Lua51'}):parse(payloadSource)
hoistedAst = Steps.Vmify:new():apply(hoistedAst)
local runtimeCountsBeforeHoist = controlFlowCounts(hoistedAst.vmRuntime)
local runtimeStringSet, runtimeStringCount = {}, 0
visitExpression(hoistedAst.vmRuntime, hoistedAst, function(node)
    if node.kind == Ast.AstKind.StringExpression and not runtimeStringSet[node.value] then
        runtimeStringSet[node.value], runtimeStringCount = true, runtimeStringCount + 1
    end
end)
local hoistEncrypt = Steps.EncryptStrings:new({HoistVmStrings = true})
math.randomseed(31)
hoistedAst = hoistEncrypt:apply(hoistedAst)
assert(countKind(hoistedAst.vmRuntime, Ast.AstKind.StringExpression) == 0,
    'Hoisted VM runtime still contains string literals on its execution path')
local runtimeCache = hoistedAst.vmRuntime.body.statements
assert(runtimeCache[1].kind == Ast.AstKind.LocalVariableDeclaration
    and runtimeCache[2].kind == Ast.AstKind.LocalVariableDeclaration
    and #runtimeCache[1].ids > 0 and #runtimeCache[1].expressions > 0
    and #runtimeCache[2].ids > 0 and #runtimeCache[2].expressions > 0,
    'Hoisted runtime cache locals were not initialized')
local afterHoistCounts = controlFlowCounts(hoistedAst.vmRuntime)
for key, value in pairs(runtimeCountsBeforeHoist) do
    assert(afterHoistCounts[key] == value,
        'String hoisting changed VM runtime ' .. key .. ' count')
end
local plaintextFound, encryptedDataStrings = false, 0
visitast(hoistedAst, function(node)
    if node.kind == Ast.AstKind.StringExpression and node.value == plaintext then
        plaintextFound = true
    end
end)
visitExpression(hoistedAst.vmData, hoistedAst, function(node)
    if node.kind == Ast.AstKind.StringExpression then encryptedDataStrings = encryptedDataStrings + 1 end
end)
assert(not plaintextFound and encryptedDataStrings > 0,
    'VM prototype data retained plaintext or lost encrypted string constants')
local cacheInitializer
for _, statement in ipairs(hoistedAst.body.statements) do
    if statement.kind == Ast.AstKind.LocalVariableDeclaration
        and statement.expressions and statement.expressions[1]
        and statement.expressions[1].kind == Ast.AstKind.TableConstructorExpression then
        cacheInitializer = statement.expressions[1]
    end
end
local encryptedCacheStrings = 0
if cacheInitializer then
    visitExpression(cacheInitializer, hoistedAst, function(node)
        if node.kind == Ast.AstKind.StringExpression then encryptedCacheStrings = encryptedCacheStrings + 1 end
    end)
end
assert(cacheInitializer and encryptedCacheStrings == runtimeStringCount,
    'Distinct runtime strings were not hoisted into an encrypted outer initializer')

-- A second hoisting pass sees no runtime string literals. It adds no empty
-- cache declaration and the two decoder layers still execute correctly.
local repeatedAst = Parser:new({LuaVersion = 'Lua51'}):parse('return 42,nil,...')
repeatedAst = Steps.Vmify:new():apply(repeatedAst)
math.randomseed(47)
repeatedAst = hoistEncrypt:apply(repeatedAst)
local repeatedRuntime = repeatedAst.vmRuntime
local firstCache, secondCache = repeatedRuntime.body.statements[1], repeatedRuntime.body.statements[2]
local runtimeBodyLength = #repeatedRuntime.body.statements
repeatedAst = hoistEncrypt:apply(repeatedAst)
assert(repeatedAst.vmRuntime == repeatedRuntime
    and repeatedRuntime.body.statements[1] == firstCache
    and repeatedRuntime.body.statements[2] == secondCache
    and #repeatedRuntime.body.statements == runtimeBodyLength,
    'Repeated string encryption added empty runtime cache declarations')
visitast(repeatedRuntime, function(node)
    if node.kind == Ast.AstKind.LocalVariableDeclaration then
        assert(#node.ids > 0, 'Repeated hoisting emitted an empty local declaration')
    end
end)
local repeatedChunk = compile('return 42,nil,...', {
    {Name = 'Vmify'},
    {Name = 'EncryptStrings', Settings = {HoistVmStrings = true}},
    {Name = 'EncryptStrings', Settings = {HoistVmStrings = true}},
}, 47)
result = pack(repeatedChunk(7, nil))
assert(result.n == 4 and result[1] == 42 and result[2] == nil
    and result[3] == 7 and result[4] == nil,
    'Repeated EncryptStrings hoisting changed simple results or return arity')

-- Exercise the final Medium ordering, including Cff exclusion before numeric
-- rewriting, with a user string stored in the VM prototype table.
local payloadChunk = compile(payloadSource, mediumSteps, 17)
result = pack(payloadChunk('tail', nil))
assert(result.n == 5 and result[1] == plaintext and result[2] == plaintext
    and result[3] == 'hoist_second_value' and result[4] == 'tail' and result[5] == nil,
    'Final Medium pipeline changed hoisted payload strings or result arity')

print('Cff native VM exclusion and captured closure checks passed')

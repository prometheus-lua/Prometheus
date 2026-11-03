local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

local oldPath = package.path
package.path = 'src/?.lua;' .. package.path
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Source = require('prometheus.source')
local visitast = require('prometheus.visitast')
local Steps = require('prometheus.steps')
local Watermark = require('prometheus.steps.Watermark')
local Emit = require('prometheus.vm.emit')
local Compiler = require('prometheus.vm.compiler')
local shareCffStrings = require('prometheus.cff.strings')
package.path = oldPath

local parser = Parser:new({LuaVersion = 'Lua51'})
local originalPath = 'step-sources-input.lua'

local function parse(code)
    return parser:parse(code, originalPath)
end

local function findNode(root, kind, predicate)
    local found
    Source.walk(root, function(node)
        if not found and node.kind == kind and (not predicate or predicate(node)) then found = node end
    end)
    return found
end

local function checkSpans(root, predicate)
    local count = 0
    Source.walk(root, function(node)
        count = count + 1
        assert(type(node.sourceSpan) == 'table', 'missing source span on ' .. tostring(node.kind))
        assert(predicate(node.sourceSpan, node), 'unexpected source span on ' .. tostring(node.kind))
    end)
    assert(count > 0, 'expected AST nodes')
end

local function original(span)
    return span.source.path == originalPath
end

local function internal(label)
    return function(span)
        return span.source.internal and span.source.path:find('prometheus-internal://' .. label .. '/', 1, true) == 1
    end
end

local function hasInternal(root, label)
    local found = false
    Source.walk(root, function(node)
        local span = node.sourceSpan
        if span and span.source.internal and span.source.path:find('prometheus-internal://' .. label .. '/', 1, true) == 1 then
            found = true
        end
    end)
    return found
end

-- Replacing one literal with an expression tree keeps the original source span.
local numbers = parse('return 42')
Steps.NumbersToExpressions:new({Threshold = 1, InternalThreshold = 0}):apply(numbers)
checkSpans(numbers.body.statements[1].args[1], original)

local split = parse('return "abcdef"')
Steps.SplitStrings:new({ConcatenationType = 'strcat', MinLength = 2, MaxLength = 2, Threshold = 1}):apply(split)
checkSpans(split.body.statements[1].args[1], original)

local customSplitStep = Steps.SplitStrings:new({ConcatenationType = 'custom', CustomFunctionType = 'inline',
    MinLength = 2, MaxLength = 2, Threshold = 1})
local customSplitA = parse('return "abcdef"')
local customSplitB = parse('return "uvwxyz"')
customSplitStep:apply(customSplitA)
customSplitStep:apply(customSplitB)
assert(hasInternal(customSplitA, 'SplitStrings.CustomFunction')
    or hasInternal(customSplitA, 'SplitStrings.CustomFunction1')
    or hasInternal(customSplitA, 'SplitStrings.CustomFunction2'), 'custom split helper should have an internal source')
local function snippetPath(root)
    local path
    Source.walk(root, function(node)
        local span = node.sourceSpan
        if not path and span and span.source.path:find('prometheus-internal://SplitStrings.CustomFunction', 1, true) == 1 then
            path = span.source.path
        end
    end)
    return path
end
assert(snippetPath(customSplitA) ~= snippetPath(customSplitB),
    'reusing a SplitStrings step should allocate unique helper source IDs')

-- ConstantArray keeps transformed value accesses tied to the replaced literal,
-- while decoder and array support code receives internal source identities.
local constants = parse('return "one", "two"')
local constantStep = Steps.ConstantArray:new({Encoding = 'mixed', StringsOnly = true, Rotate = true})
constantStep:apply(constants)
local constantReturn = findNode(constants, 'ReturnStatement', function(node) return original(node.sourceSpan) end)
checkSpans(constantReturn.args[1], original)
assert(findNode(constants, 'ForStatement'), 'expected generated rotation/decoder loop')
local decoderSource = false
Source.walk(constants, function(node)
    local span = node.sourceSpan
    if span and span.source.path:find('prometheus-internal://ConstantArray.MixedDecoder/', 1, true) == 1 then
        decoderSource = true
    end
end)
assert(decoderSource, 'decoder snippet should keep its internal source identity')
local constantAgain = parse('return "three", "four"')
constantStep:apply(constantAgain)
local function firstGeneratedArrayPath(root)
    local path
    Source.walk(root, function(node)
        if not path and node.kind == 'LocalVariableDeclaration' and internal('ConstantArray')(node.sourceSpan) then
            path = node.sourceSpan.source.path
        end
    end)
    return path
end
assert(firstGeneratedArrayPath(constants) ~= firstGeneratedArrayPath(constantAgain),
    'reusing a ConstantArray step should allocate unique generated source IDs')

local encrypted = parse('return "secret"')
Steps.EncryptStrings:new({}):apply(encrypted)
local encryptedReturn = findNode(encrypted, 'ReturnStatement', function(node) return original(node.sourceSpan) end)
checkSpans(encryptedReturn.args[1], original)
local decryptSource = false
Source.walk(encrypted, function(node)
    local span = node.sourceSpan
    if span and span.source.path:find('prometheus-internal://EncryptStrings.Decryptor/', 1, true) == 1 then
        decryptSource = true
    end
end)
assert(decryptSource, 'decryptor snippet should keep its internal source identity')

local proxified = parse('local x = 3; return x')
Steps.ProxifyLocals:new({LiteralType = 'number'}):apply(proxified, {
    namegenerator = function() return 'source_test' end,
})
local proxifiedValue = proxified.body.statements[#proxified.body.statements].args[1]
assert(original(proxifiedValue.sourceSpan), 'proxified expression should retain the replaced expression origin')
assert(findNode(proxified, 'LocalVariableDeclaration', function(node)
    return node.sourceSpan.source.path:find('prometheus-internal://ProxifyLocals/', 1, true) == 1
end), 'proxify support declarations should be marked generated')
checkSpans(proxified, function(span)
    return span.source.path == originalPath or span.source.path:find('prometheus-internal://ProxifyLocals/', 1, true) == 1
end)

local vararg = parse('local f = function(x) return x end; return f')
Steps.AddVararg:new():apply(vararg)
local addedVararg = findNode(vararg, 'FunctionLiteralExpression').args[2]
assert(addedVararg.kind == 'VarargExpression' and internal('AddVararg')(addedVararg.sourceSpan),
    'added vararg should have its own generated source')

local wrapped = parse('return 1')
local movedBody = wrapped.body
Steps.WrapInFunction:new({Iterations = 1}):apply(wrapped)
assert(wrapped.body.sourceSpan.source.internal, 'wrapper block should be generated')
assert(wrapped.body.statements[1].args[1].base.body == movedBody,
    'wrapping should preserve the moved source body')
assert(original(movedBody.statements[1].args[1].sourceSpan), 'moved source body origin should be preserved')

local watermarked = parse('return 1')
Watermark:new({Content = 'mark', CustomVariable = '_mark'}):apply(watermarked)
assert(internal('Watermark')(watermarked.body.statements[1].sourceSpan), 'watermark code should be generated')

local checked = parse('return 1')
local scheduled
Steps.WatermarkCheck:new({Content = 'mark'}):apply(checked, {
    namegenerator = function() return 'mark' end,
    addStep = function(_, step) scheduled = step end,
})
assert(internal('WatermarkCheck')(checked.body.statements[1].sourceSpan), 'watermark check should be generated')
assert(scheduled and scheduled.Name == 'Watermark', 'watermark step should still be scheduled')

local untouched = parse('return 1')
local antiTamper = Steps.AntiTamper:new({})
antiTamper:apply(untouched, {PrettyPrint = false, SourceMap = true})
assert(#untouched.body.statements == 1, 'AntiTamper should be skipped with source maps enabled')

local shared = parse('return "repeat", "repeat"')
shareCffStrings(shared)
assert(internal('Cff.StringPool')(shared.body.statements[1].sourceSpan), 'Cff string pool should be generated')
assert(original(shared.body.statements[2].args[1].sourceSpan), 'pooled lookup should inherit the replaced literal origin')

local vmAst = Emit.ast(Compiler:compile(parse('return 7')))
checkSpans(vmAst, internal('VM'))

print('Step source propagation checks passed')

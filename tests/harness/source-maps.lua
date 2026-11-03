local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local SourceMap = Prometheus.SourceMap
local Source = require('prometheus.source')
local Parser = require('prometheus.parser')
local Ast = require('prometheus.ast')
local Json = require('prometheus.json')

-- Independent v3 fixture: source/name/line deltas persist between lines,
-- generated columns reset, and column-only segments remain unmapped.
local fixture = SourceMap.decode([[{"version":3,"file":"out.lua","sources":["one.lua","two.lua"],"names":["value"],"sourcesContent":["one",null],"mappings":"AAAAA;ACGA;ADDA;A;KACA"}]])
assert(SourceMap.lookup(fixture, 1).line == 1)
assert(SourceMap.lookup(fixture, 2).source == 'two.lua')
assert(SourceMap.lookup(fixture, 2).line == 4)
assert(SourceMap.lookup(fixture, 2).content == nil)
assert(SourceMap.lookup(fixture, 3).line == 3)
assert(SourceMap.lookup(fixture, 4) == nil)
assert(SourceMap.lookup(fixture, 5).line == 4)
assert(SourceMap.lookup(SourceMap.decode(SourceMap.encode(fixture)), 5).line == 4)
assert(not pcall(SourceMap.decode, [[{"version":3,"sources":{},"names":[],"mappings":""}]]))
for _, mapping in ipairs({'!', 'g', 'AA', 'AAAAAA', 'ACAA', 'AADA', 'AAAA,', 'AAAA,D'}) do
    local map = {version = 3, sources = {'one.lua'}, names = {}, mappings = mapping}
    assert(not pcall(SourceMap.encode, map), 'Should reject mapping ' .. mapping)
end
assert(Json.decode('"\\ud83d\\ude00"') == '\240\159\152\128')
for _, input in ipairs({'01', '[1,]', '{"a":}', '"\\ud800"', 'true false'}) do
    assert(not pcall(Json.decode, input), 'Should reject JSON ' .. input)
end

local function pipeline(pretty, steps, dialect)
    return Prometheus.Pipeline:fromConfig({LuaVersion = dialect or 'Lua51', Seed = 7,
        SourceMap = true, PrettyPrint = pretty, Steps = steps or {}})
end

-- Split tokens even where the grammar previously needed no space. The source
-- span on the enclosing operator supplies its line independently of operands.
for _, pretty in ipairs({false, true}) do
    local ast = Parser:new({LuaVersion = 'Lua51'}):parse('return 1', 'split.lua')
    local expression = Source.inherit(Ast.AddExpression(Ast.NumberExpression(1), Ast.NumberExpression(2)),
        ast.body.statements[1].args[1])
    ast.body.statements[1].args[1] = expression
    expression.rhs.sourceSpan = {source = expression.sourceSpan.source, startLine = 2,
        startColumn = 1, endLine = 2, endColumn = 2, startOffset = 0, endOffset = 1}
    local code, map = pipeline(pretty):unparse(ast)
    assert(code:find('\n', 1, true))
    assert(assert(loadstring(code))() == 3)
    local found = false
    for line = 1, select(2, code:gsub('\n', '')) + 1 do
        local mapped = SourceMap.lookup(map, line)
        if mapped and mapped.line == 2 then found = true end
    end
    assert(found, 'Missing mapping for RHS token')
end

local codeExamples = {
    'return 1 .. .2',
    'return 1- -2, - -3',
    'local f=function() return 3 end; f(); (function() return f() end)(); return f()',
    'local t={a="\\00012",["b"]=2}; return #t.a,t.b',
    'local function f(...) return (...) end; return f(nil,2)',
    'local x=1; return function() return x end',
    'return [[first\nsecond]], "\\n\\r\\000"',
}
for _, code in ipairs(codeExamples) do
    local original = assert(loadstring(code))
    for _, pretty in ipairs({false, true}) do
        local generated, map = pipeline(pretty):apply(code, 'examples.lua')
        local result = {assert(loadstring(generated))()}
        local expected = {original()}
        for i, value in ipairs(expected) do
            if type(value) ~= 'function' then assert(result[i] == value, generated) end
        end
        assert(not generated:find('\0', 1, true), 'Private annotations escaped into output')
        assert(SourceMap.decode(SourceMap.encode(map)).version == 3)
    end
end

-- Genuine runtime errors must recover the failing user line through ordinary
-- transformations and Cff. Generated VM frames deliberately remain internal.
local input = 'local x={}\nlocal function fail()\n  return x.missing + 1\nend\nreturn fail()\n'
local configs = {
    {},
    {{Name = 'NumbersToExpressions', Settings = {Threshold = 1}}},
    {{Name = 'SplitStrings', Settings = {Threshold = 1}}},
    {{Name = 'EncryptStrings', Settings = {}}},
    {{Name = 'ConstantArray', Settings = {Threshold = 1}}},
    {{Name = 'WrapInFunction', Settings = {}}},
    {{Name = 'ProxifyLocals', Settings = {}}},
    {{Name = 'Cff', Settings = {}}},
}
for _, steps in ipairs(configs) do
    for _, pretty in ipairs({false, true}) do
        local generated, map = pipeline(pretty, steps):apply(input, 'failing.lua')
        local chunk = assert(loadstring(generated, '@mapped.lua'))
        local ok, err = pcall(chunk)
        assert(not ok, 'Fixture must fail')
        local line = tonumber(tostring(err):match('mapped%.lua:(%d+):'))
        assert(line, tostring(err))
        local recovered = SourceMap.lookup(map, line)
        assert(recovered and recovered.source == 'failing.lua' and recovered.line == 3,
            (steps[1] and steps[1].Name or 'Minify') .. ': ' .. tostring(err) .. '\n' ..
            (recovered and recovered.source .. ':' .. recovered.line or 'unmapped'))
    end
end
for _, pretty in ipairs({false, true}) do
    local generated, map = pipeline(pretty, {{Name = 'Vmify'}}):apply(input, 'failing.lua')
    local ok, err = pcall(assert(loadstring(generated, '@mapped.lua')))
    assert(not ok)
    local recovered = SourceMap.lookup(map, tonumber(tostring(err):match('mapped%.lua:(%d+):')))
    assert(recovered and recovered.source:match('^prometheus%-internal://VM/'), tostring(err))
end

local unmappedPipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 7, Steps = {}})
local plain, absent = unmappedPipeline:apply('return 1', 'plain.lua')
assert(absent == nil and not plain:find('\n', 1, true))
local omitted = pipeline(false)
omitted.SourceMapIncludeSources = false
local _, map = omitted:apply('return 1', 'plain.lua')
assert(map.sourcesContent == nil)
assert(not SourceMap.encode(map):find('sourcesContent', 1, true))

print('Source-map codec, token emission, transformation and runtime recovery checks passed')

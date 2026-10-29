local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Ast = require('prometheus.ast')
local Parser = require('prometheus.parser')
local Compiler = require('prometheus.vm.compiler')
local Layout = require('prometheus.vm.layout')
local Data = require('prometheus.vm.data')
local Emit = require('prometheus.vm.emit')
local visitast = require('prometheus.visitast')

local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= 'table' then return left == right end
    for key, value in pairs(left) do if not equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end
local values = {}
for i = 1, 40 do values[i] = tostring(i * 11) end
local source = 'local values={' .. table.concat(values, ',') .. [[}
    local flag = false
    return function(a, ...)
        flag = not flag
        return values[1], values[40], flag, a, ...
    end
]]
local proto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(source))
local signatures = {}
for _, seed in ipairs({1, 4, 17, 99}) do
    math.randomseed(seed)
    local layout = Layout.new()
    local encoded, count, rootId = Data.encode(proto, layout)
    signatures[encoded] = true
    math.randomseed(seed)
    local repeated = Data.encode(proto, Layout.new())
    assert(encoded == repeated, 'same seed must reproduce the scattered data')
    local shards = assert(loadstring('return ' .. encoded))()
    assert(#shards >= 3 and #shards <= 5)
    local destinations, seen = {}, {}
    local minimum, maximum = math.huge, 0
    for shardId, shard in ipairs(shards) do
        minimum, maximum = math.min(minimum, #shard), math.max(maximum, #shard)
        for _, record in ipairs(shard) do
            local destination, key = record[1], record[2]
            assert(destination >= 1 and destination <= count and type(key) == 'number')
            seen[destination] = seen[destination] or {}
            assert(not seen[destination][key], 'scattered assignments must be unique')
            seen[destination][key] = true
            destinations[destination] = destinations[destination] or {}
            destinations[destination][shardId] = true
        end
    end
    assert(maximum - minimum <= 1 and minimum > 0, 'shards must be balanced and populated')
    local rebuild = assert(loadstring(Data.rebuild .. 'return rebuild'))()
    local root = rebuild(shards, count, rootId)
    assert(next(shards) == nil, 'reconstruction must release consumed shards')
    local function check(actual, original)
        local fieldCount = 0
        for key in pairs(actual) do
            assert(type(key) == 'number', 'prototype keys must not contain fixed strings')
            fieldCount = fieldCount + 1
        end
        assert(fieldCount == 7)
        for _, name in ipairs({'constants', 'captures', 'params', 'vararg', 'maxRegister'}) do
            assert(equal(actual[layout.fields[name]], original[name]), name .. ' changed during reconstruction')
        end
        local code = actual[layout.fields.code]
        assert(#code == #original.code)
        for i, instruction in ipairs(original.code) do
            assert(equal(code[i], layout:encode(instruction)), 'instruction changed during reconstruction')
        end
        local children = actual[layout.fields.children]
        assert(#children == #original.children)
        for i, child in ipairs(original.children) do check(children[i], child) end
    end
    check(root[1], proto)
    -- Identify the reconstructed root code/constants arrays and check that their
    -- entries, rather than only the prototype metadata, came from multiple shards.
    local raw = assert(loadstring('return ' .. encoded))()
    local byId = {}
    for i = 1, count do byId[i] = {} end
    for _, shard in ipairs(raw) do
        for _, record in ipairs(shard) do
            byId[record[1]][record[2]] = record[4] and byId[record[3]] or record[3]
        end
    end
    for _, field in ipairs({'code', 'constants'}) do
        local array = byId[rootId][1][layout.fields[field]]
        local id
        for index, value in ipairs(byId) do if value == array then id = index end end
        local spread = 0
        for _ in pairs(destinations[id]) do spread = spread + 1 end
        assert(spread > 1, field .. ' entries were not scattered across shards')
    end
end
local distinct = 0
for _ in pairs(signatures) do distinct = distinct + 1 end
assert(distinct > 1, 'different seeds must change scattered data')

local blankAst = Emit.ast(Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse('return 42')))
local fixed = {code=true, constants=true, captures=true, params=true, vararg=true,
    maxRegister=true, children=true, n=true}
visitast(blankAst, function(node)
    if node.kind == 'StringExpression' then
        assert(not fixed[node.value], 'fixed VM key remains in generated AST: ' .. node.value)
    end
end)
assert(blankAst.vmData.kind == 'TableConstructorExpression')
local runtimeWrapper = Ast.TopNode(Ast.Block({Ast.ReturnStatement({blankAst.vmRuntime})},
    blankAst.body.scope), blankAst.globalScope)
visitast(runtimeWrapper, function(node)
    if node.kind == 'VariableExpression' and not node.scope.isGlobal then
        assert(node.scope:getVariableName(node.id) ~= 'rebuild', 'reconstruction leaked into runtime')
    end
end)

-- Count helper invocations while repeatedly executing a closure from the chunk.
math.randomseed(87123)
local emitted = Emit.source(proto)
math.randomseed(87123)
assert(emitted == Emit.source(proto), 'same seed must reproduce the VM source')
local instrumented, replacements = emitted:gsub('local function rebuild%(shards, count, root%)',
    'local reconstructionCount = 0\nlocal function rebuild(shards, count, root)\nreconstructionCount = reconstructionCount + 1')
assert(replacements == 1)
instrumented = instrumented:gsub('return tables%[root%]',
    'assert(reconstructionCount == 1); return tables[root]')
local closure = assert(loadstring(instrumented))()
local function pack(...) return {n = select('#', ...), ...} end
for i = 1, 5 do
    local result = pack(closure(nil, 7, nil))
    assert(result[1] == 11 and result[2] == 440 and result[3] == (i % 2 == 1))
    assert(result.n == 6 and result[4] == nil and result[5] == 7 and result[6] == nil)
end

for _, preset in ipairs({'Vmify', 'Medium', 'Strong'}) do
    local config = require('src.presets')[preset]
    local pipelineConfig = {LuaVersion='Lua51', Seed=17, Steps=config.Steps}
    local first = Prometheus.Pipeline:fromConfig(pipelineConfig):apply(source)
    local fn = assert(loadstring(first))()
    assert(select('#', fn(nil, 7, nil)) == 6, preset .. ' changed trailing nil results')
end
print('VM scattered data, randomized keys, and reconstruction checks passed')

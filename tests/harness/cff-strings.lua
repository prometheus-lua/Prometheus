local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Parser = require('prometheus.parser')
local Unparser = require('prometheus.unparser')
local visitast = require('prometheus.visitast')
local shareStrings = require('prometheus.cff.strings')
local Steps = require('prometheus.steps')
local Presets = require('src.presets')

local parser = Parser:new({LuaVersion = 'Lua51'})
local unparser = Unparser:new({LuaVersion = 'Lua51'})
local function inventory(ast)
    local counts = {}
    visitast(ast, function(node)
        if node.kind == 'StringExpression' then counts[node.value] = (counts[node.value] or 0) + 1 end
    end)
    return counts
end
local function unique(ast)
    local counts = inventory(ast)
    for value, count in pairs(counts) do
        assert(count == 1, 'string embedded more than once: ' .. string.format('%q', value))
    end
    return counts
end
local function pack(...) return {n = select('#', ...), ...} end

-- Empty/unique inputs need no pool. Sharing is idempotent.
for _, source in ipairs({'return ...', 'return "single", 7'}) do
    local ast = parser:parse(source)
    local statements, variables = #ast.body.statements, #ast.body.scope.variables
    assert(shareStrings(ast) == ast)
    assert(#ast.body.statements == statements and #ast.body.scope.variables == variables)
end
local source = [[
    local object = {message = 'shared', [''] = 'shared'}
    return {function()
        return function(delta)
            object.message = object.message .. delta
            return object.message, '', 'shared', 'a\000b', '\"quoted\"'
        end
    end, 'shared', '', 'a\000b', '\"quoted\"'}, ...
]]
local ast = parser:parse(source)
shareStrings(ast)
local counts = unique(ast)
assert(counts.shared == 1 and counts['a\000b'] == 1 and counts[''] == 1)
local pool = ast.body.statements[1]
assert(pool.kind == 'LocalVariableDeclaration' and #pool.ids == 1)
local statements, variables = #ast.body.statements, #ast.body.scope.variables
shareStrings(ast)
assert(ast.body.statements[1] == pool and #ast.body.statements == statements
    and #ast.body.scope.variables == variables, 'sharing must be idempotent')
local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion='Lua51', Seed=17, Steps={}})
pipeline:renameVariables(ast)
local chunk = assert(loadstring(unparser:unparse(ast)))
local returned = pack(chunk(nil, false, nil))
assert(returned.n == 4 and returned[2] == nil and returned[3] == false and returned[4] == nil)
local values = returned[1]
assert(values[2] == 'shared' and values[3] == '' and values[4] == 'a\000b' and values[5] == '"quoted"')
local inner = values[1]()
collectgarbage('collect')
local result = pack(inner('!'))
assert(result.n == 5 and result[1] == 'shared!' and result[2] == '' and result[3] == 'shared'
    and result[4] == 'a\000b' and result[5] == '"quoted"')
assert(inner('?') == 'shared!?', 'shared pool broke closure state')

-- One table binding handles more repeated values than Lua's local variable limit.
local entries = {}
for i = 1, 250 do
    entries[#entries + 1] = string.format('%q', 'shared_value_' .. i)
    entries[#entries + 1] = entries[#entries]
end
local large = parser:parse('return {' .. table.concat(entries, ',') .. '}')
shareStrings(large)
unique(large)
pipeline:renameVariables(large)
local values = assert(loadstring(unparser:unparse(large)))()
assert(#values == 500 and values[1] == 'shared_value_1' and values[500] == 'shared_value_250')

-- All Cff paths must share newly generated diagnostics and argument-pack keys.
local program = [[
    local function gather(...) return ... end
    local total = 0
    for i = 1, 3 do total = total + i end
    for i = 1, 2 do total = total + i end
    return gather(total, nil, false, ...)
]]
local configurations = {
    {{Name='Cff'}},
    {{Name='Vmify'}, {Name='Cff'}},
    {{Name='Vmify'}, {Name='Cff', Settings={ExcludeVm=true}}},
    Presets.Medium.Steps,
}
for _, seed in ipairs({1, 4, 17}) do
    for _, steps in ipairs(configurations) do
        local output = Prometheus.Pipeline:fromConfig({LuaVersion='Lua51', Seed=seed, Steps=steps}):apply(program)
        local counts = unique(parser:parse(output))
        assert(counts["'for' initial value must be a number"] == 1,
            'Cff must retain exactly one copy of its loop diagnostics')
        assert(counts.n == 1, 'Cff must share its counted-value key')
        local result = pack(assert(loadstring(output))(nil, 'last', nil))
        assert(result.n == 6 and result[1] == 9 and result[2] == nil and result[3] == false
            and result[4] == nil and result[5] == 'last' and result[6] == nil)
    end
end

-- Caching error text must preserve failure behavior, not merely success paths.
local badLoop = Steps.Cff:new():apply(parser:parse('for i = ... , 3 do end'))
unique(badLoop)
pipeline:renameVariables(badLoop)
local loop = assert(loadstring(unparser:unparse(badLoop)))
local ok, err = pcall(loop, {})
assert(not ok and tostring(err):find("'for' initial value must be a number", 1, true))
print('Cff shared string literals, scope, and Medium output checks passed')

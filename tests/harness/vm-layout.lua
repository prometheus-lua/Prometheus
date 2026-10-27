local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local Parser = require('prometheus.parser')
local Compiler = require('prometheus.vm.compiler')
local Emit = require('prometheus.vm.emit')
local Layout = require('prometheus.vm.layout')
local opcodes = require('prometheus.vm.opcodes')

local names = {}
local namesById = {}
for name, id in pairs(opcodes) do
    names[#names + 1] = name
    namesById[id] = name
end
table.sort(names)

local function signature(layout)
    local parts = {}
    for _, name in ipairs(names) do
        parts[#parts + 1] = name .. ':' .. tostring(layout.opcodes[name])
    end
    for id = 1, #names do parts[#parts + 1] = tostring(layout.ids[id]) end
    for i = 1, 4 do parts[#parts + 1] = tostring(layout.operands[i]) end
    return table.concat(parts, ',')
end

local function opcodeSignature(layout)
    local parts = {}
    for _, name in ipairs(names) do
        parts[#parts + 1] = name .. ':' .. tostring(layout.opcodes[name])
    end
    return table.concat(parts, ',')
end

local function seeded(seed)
    math.randomseed(seed)
    return Layout.new()
end

local first = seeded(87123)
assert(signature(first) == signature(seeded(87123)), 'layout must repeat for the same seed')
local opcodeLayouts, operandLayouts = {}, {}
for _, seed in ipairs({1, 4, 17, 99, 87123, 234567}) do
    local layout = seeded(seed)
    local seen = {}
    for _, name in ipairs(names) do
        local id = layout.opcodes[name]
        assert(type(id) == 'number' and id >= 1 and id <= #names and id % 1 == 0)
        assert(not seen[id], 'opcode IDs must be a permutation')
        seen[id] = true
    end
    for id = 1, #names do
        assert(layout.ids[id] == layout.opcodes[namesById[id]],
            'canonical opcode lookup must match the name lookup')
    end
    opcodeLayouts[opcodeSignature(layout)] = true
    local slots = {}
    for i = 1, 4 do slots[layout.operands[i]] = true end
    assert(slots[2] and slots[3] and slots[4] and slots[5])
    operandLayouts[table.concat(layout.operands, ',')] = true
end
local distinctOpcodes, distinctOperands = 0, 0
for _ in pairs(opcodeLayouts) do distinctOpcodes = distinctOpcodes + 1 end
for _ in pairs(operandLayouts) do distinctOperands = distinctOperands + 1 end
assert(distinctOpcodes > 1, 'different seeds must change opcode assignments')
assert(distinctOperands > 1, 'different seeds must change operand layouts')

local source = [[
    local function pack(...) return {n = select('#', ...), ...} end
    local function fixed(a, b, c) return a, b, c end
    local function pair(a, b) return a, b end
    local function empty() end
    empty()
    local zero, one = pack(fixed()), pack(fixed(nil))
    local two, three = pack(fixed(2, nil)), pack(fixed(3, nil, 5))
    local first, second = pair(8, nil)
    assert(zero.n == 3 and one.n == 3 and zero[1] == nil and one[1] == nil)
    assert(two.n == 3 and two[1] == 2 and two[2] == nil and two[3] == nil)
    assert(three.n == 3 and three[1] == 3 and three[2] == nil and three[3] == 5)
    assert(first == 8 and second == nil)
    local function make(start)
        local total = start
        local unused = {}
        return function(step, ...)
            total = total + step
            return pack(total, ...)
        end
    end
    local closure = make(10)
    local object = {value = 1}
    function object:bump(step, ...) self.value = self.value + step; return pack(self.value, ...) end
    local values = {}
    for i = 1, 4 do values[i] = i * i end
    local left = closure(2, nil, 7, nil)
    local right = object:bump(3, 'method', nil)
    local keyed = {left[1], right[1], nil, label = 'ok', [8] = values[4]}
    local rootArgs = pack(...)
    return left, right, values, keyed, rootArgs, object.value
]]
local proto = Compiler:compile(Parser:new({LuaVersion = 'Lua51'}):parse(source))

local function clone(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[clone(key)] = clone(item) end
    return result
end
local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= 'table' then return left == right end
    for key, value in pairs(left) do if not equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil and right[key] ~= nil then return false end end
    return true
end
local original = clone(proto)

-- Run all 24 physical operand orders, with the opcode field left in slot one.
local function permutations(values, index, output)
    index = index or 1
    output = output or {}
    if index > #values then
        output[#output + 1] = {unpack(values)}
        return
    end
    for i = index, #values do
        values[index], values[i] = values[i], values[index]
        permutations(values, index + 1, output)
        values[index], values[i] = values[i], values[index]
    end
    return output
end
local allOrders = permutations({2, 3, 4, 5})
assert(#allOrders == 24)
for index, order in ipairs(allOrders) do
    local layout = seeded(3000 + index)
    layout.operands = order
    local run = assert(loadstring(Emit.source(proto, layout)))
    local left, right, values, keyed, rootArgs, objectValue = run('root', nil, 99, nil)
    assert(left.n == 4 and left[1] == 12 and left[2] == nil and left[3] == 7 and left[4] == nil)
    assert(right.n == 3 and right[1] == 4 and right[2] == 'method' and right[3] == nil)
    assert(values[1] == 1 and values[2] == 4 and values[3] == 9 and values[4] == 16)
    assert(keyed[1] == 12 and keyed[2] == 4 and keyed[3] == nil)
    assert(keyed.label == 'ok' and keyed[8] == 16)
    assert(rootArgs.n == 4 and rootArgs[1] == 'root' and rootArgs[2] == nil)
    assert(rootArgs[3] == 99 and rootArgs[4] == nil and objectValue == 4)
    assert(equal(proto, original), 'emission must not rewrite canonical compiler IR')
end

-- The ordinary build path also chooses a profile while retaining canonical IR.
assert(loadstring(Emit.source(proto)))('build')
assert(equal(proto, original), 'default emission must not rewrite canonical compiler IR')
print('VM opcode and operand layout checks passed')

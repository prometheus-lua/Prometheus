-- Choose instruction encoding and metadata keys per VM. Compiler IR stays semantic.
local opcodes = require('prometheus.vm.opcodes')
local shuffle = require('prometheus.util').shuffle
local fields = {'code', 'constants', 'captures', 'params', 'vararg', 'maxRegister', 'children'}
local Layout = {}
Layout.__index = Layout

function Layout.new()
    local entries, ids = {}, {}
    for name, id in pairs(opcodes) do
        entries[#entries + 1] = {name = name, id = id}
    end
    table.sort(entries, function(left, right) return left.id < right.id end)
    for i = 1, #entries do ids[i] = i end
    shuffle(ids)
    local layout = setmetatable({opcodes = {}, ids = {},
        operands = shuffle({2, 3, 4, 5})}, Layout)
    for i, entry in ipairs(entries) do
        layout.opcodes[entry.name] = ids[i]
        layout.ids[entry.id] = ids[i]
    end
    layout.fields = {}
    local used = {}
    for _, name in ipairs(fields) do
        local key
        repeat key = math.random(1024, 16777215) until not used[key]
        used[key] = true
        layout.fields[name] = key
    end
    -- Counted tuples also contain positive array indices, so keep metadata negative.
    layout.countKey = -math.random(1024, 16777215)
    return layout
end

function Layout:encode(instruction)
    local encoded = {self.ids[instruction[1]] or instruction[1]}
    local length = 1
    for operand = 2, #instruction do
        local slot = assert(self.operands[operand - 1], 'Missing VM operand slot')
        encoded[slot] = instruction[operand]
        length = math.max(length, slot)
    end
    return encoded, length
end

return Layout

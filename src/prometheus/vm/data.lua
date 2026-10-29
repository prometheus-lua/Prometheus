-- Scatter the emitted table graph; rebuild ordinary tables once before VM startup.
local Ast = require('prometheus.ast')
local Unparser = require('prometheus.unparser')
local Enums = require('prometheus.enums')
local shuffle = require('prometheus.util').shuffle
local Data = {}

Data.rebuild = [=[
local function rebuild(shards, count, root)
    local tables = {}
    for i = 1, count do tables[i] = {} end
    for i = 1, #shards do
        local shard = shards[i]
        for j = 1, #shard do
            local record = shard[j]
            local value = record[3]
            if record[4] then value = tables[value] end
            tables[record[1]][record[2]] = value
        end
        shards[i] = nil
    end
    return tables[root]
end
]=]

function Data.encode(proto, layout)
    local function prototype(value)
        local result, code, children = {}, {}, {}
        for i, instruction in ipairs(value.code) do
            code[i] = layout:encode(instruction)
        end
        for i, child in ipairs(value.children) do children[i] = prototype(child) end
        result[layout.fields.code] = code
        result[layout.fields.children] = children
        for _, name in ipairs({'constants', 'captures', 'params', 'vararg', 'maxRegister'}) do
            result[layout.fields[name]] = value[name]
        end
        return result
    end
    local root = {prototype(proto)}
    local tables, indices, keys = {}, {}, {}
    local function collect(value)
        if indices[value] then return end
        tables[#tables + 1] = value
        indices[value] = #tables
        local sorted = {}
        for key in pairs(value) do sorted[#sorted + 1] = key end
        table.sort(sorted)
        keys[value] = sorted
        for _, key in ipairs(sorted) do
            if type(value[key]) == 'table' then collect(value[key]) end
        end
    end
    collect(root)
    local ids = {}
    for i = 1, #tables do ids[i] = i end
    shuffle(ids)
    local unparser = Unparser:new({LuaVersion = Enums.LuaVersion.Lua51})
    local records = {}
    for i, value in ipairs(tables) do
        for _, key in ipairs(keys[value]) do
            local entry, reference = value[key], ''
            if type(entry) == 'table' then
                entry, reference = ids[indices[entry]], ',1'
            end
            local literal = unparser:unparseExpression(Ast.ConstantNode(entry), 0)
            records[#records + 1] = '{' .. ids[i] .. ',' .. key .. ',' .. literal .. reference .. '}'
        end
    end
    shuffle(records)
    local shards = {}
    local count = math.random(3, 5)
    for i = 1, count do shards[i] = {} end
    for i, record in ipairs(records) do
        local shard = shards[(i - 1) % count + 1]
        shard[#shard + 1] = record
    end
    for i, shard in ipairs(shards) do shards[i] = '{' .. table.concat(shard, ',') .. '}' end
    return '{' .. table.concat(shards, ',') .. '}', #tables, ids[indices[root]]
end

return Data

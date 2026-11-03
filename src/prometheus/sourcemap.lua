-- Source Map v3 / ECMA-426. Mapping coordinates are zero based on the wire.
local Json = require('prometheus.json')
local logger = require('logger')
local SourceMap = {}
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local digits = {}
for i = 1, #alphabet do digits[alphabet:sub(i, i)] = i - 1 end

local function vlq(value)
    local number = math.abs(value) * 2 + (value < 0 and 1 or 0)
    local out = {}
    repeat
        local digit = number % 32
        number = math.floor(number / 32)
        if number > 0 then digit = digit + 32 end
        out[#out + 1] = alphabet:sub(digit + 1, digit + 1)
    until number == 0
    return table.concat(out)
end

local function decodeSegment(segment)
    local values, value, shift = {}, 0, 0
    for i = 1, #segment do
        local digit = digits[segment:sub(i, i)]
        assert(digit, 'Invalid source map: invalid Base64 VLQ digit')
        value = value + (digit % 32) * 2 ^ shift
        assert(value <= 4294967295 and shift <= 30, 'Invalid source map: VLQ overflow')
        if digit < 32 then
            local negative = value % 2 == 1
            values[#values + 1] = math.floor(value / 2) * (negative and -1 or 1)
            value, shift = 0, 0
        else shift = shift + 5 end
    end
    assert(shift == 0, 'Invalid source map: incomplete VLQ')
    assert(#values == 1 or #values == 4 or #values == 5, 'Invalid source map: segment must have 1, 4 or 5 fields')
    return values
end

function SourceMap.build(origins, count, includeSources)
    local map = {version = 3, sources = Json.array(), names = Json.array(), mappings = ''}
    if includeSources ~= false then map.sourcesContent = Json.array() end
    local ids, lines = {}, {}
    local lastSource, lastLine = 0, 0
    for i = 1, count do
        local origin = origins[i]
        if origin then
            local source = origin.source
            local id = ids[source]
            if not id then
                id = #map.sources + 1
                ids[source] = id
                map.sources[id] = source.path
                if map.sourcesContent then
                    if source.content ~= nil and not Json.isValidUtf8(source.content) then
                        logger:warn('Omitting embedded source content for ' .. source.path .. ': invalid UTF-8')
                        map.sourcesContent[id] = Json.null
                    else map.sourcesContent[id] = source.content or Json.null end
                end
            end
            local originalLine = origin.startLine - 1
            lines[i] = 'A' .. vlq(id - 1 - lastSource) .. vlq(originalLine - lastLine) .. 'A'
            lastSource, lastLine = id - 1, originalLine
        else lines[i] = '' end
    end
    map.mappings = table.concat(lines, ';')
    return map
end

local cache = setmetatable({}, {__mode = 'k'})
local function array(value, label, itemKind)
    assert(type(value) == 'table', 'Invalid source map: ' .. label .. ' must be an array')
    local count = 0
    for index, item in pairs(value) do
        assert(type(index) == 'number' and index >= 1 and index == math.floor(index),
            'Invalid source map: ' .. label .. ' must be an array')
        count = count + 1
        assert(type(item) == itemKind or (label == 'sourcesContent' and item == Json.null),
            'Invalid source map: invalid ' .. label .. ' entry')
    end
    assert(count == #value, 'Invalid source map: ' .. label .. ' must not be sparse')
end

local function validate(map)
    assert(type(map) == 'table' and map.version == 3, 'Invalid source map: expected version 3')
    assert(type(map.sources) == 'table' and type(map.names) == 'table' and type(map.mappings) == 'string',
        'Invalid source map: expected sources, names and mappings')
    array(map.sources, 'sources', 'string')
    array(map.names, 'names', 'string')
    if map.file ~= nil then assert(type(map.file) == 'string', 'Invalid source map: file must be a string') end
    if map.sourceRoot ~= nil then assert(type(map.sourceRoot) == 'string', 'Invalid source map: sourceRoot must be a string') end
    if map.sourcesContent ~= nil then
        assert(type(map.sourcesContent) == 'table' and #map.sourcesContent == #map.sources, 'Invalid source map: sourcesContent must match sources')
        array(map.sourcesContent, 'sourcesContent', 'string')
    end
    local result, sourceIndex, originalLine, originalColumn, nameIndex = {}, 0, 0, 0, 0
    local lineNumber = 0
    for line in (map.mappings .. ';'):gmatch('(.-);') do
        lineNumber = lineNumber + 1
        local generatedColumn = 0
        if line ~= '' then
            for segment in (line .. ','):gmatch('(.-),') do
                local fields = decodeSegment(segment)
                assert(fields[1] >= 0, 'Invalid source map: generated columns must be ordered')
                generatedColumn = generatedColumn + fields[1]
                if #fields > 1 then
                    sourceIndex = sourceIndex + fields[2]
                    originalLine = originalLine + fields[3]
                    originalColumn = originalColumn + fields[4]
                    assert(sourceIndex >= 0 and sourceIndex < #map.sources and originalLine >= 0 and originalColumn >= 0,
                        'Invalid source map: mapping references invalid source or position')
                    if #fields == 5 then
                        nameIndex = nameIndex + fields[5]
                        assert(nameIndex >= 0 and nameIndex < #map.names, 'Invalid source map: invalid name index')
                    end
                    if not result[lineNumber] then
                        local content = map.sourcesContent and map.sourcesContent[sourceIndex + 1]
                        result[lineNumber] = {source = map.sources[sourceIndex + 1], line = originalLine + 1,
                            content = content ~= Json.null and content or nil}
                    end
                end
            end
        end
    end
    cache[map] = result
    return map
end

function SourceMap.encode(map)
    validate(map)
    local function copyArray(items)
        local copy = Json.array()
        for i, item in ipairs(items) do copy[i] = item end
        return copy
    end
    local object = {version = map.version, sources = copyArray(map.sources), names = copyArray(map.names),
        mappings = map.mappings, file = map.file, sourceRoot = map.sourceRoot}
    if map.sourcesContent then object.sourcesContent = copyArray(map.sourcesContent) end
    return Json.encode(object)
end

function SourceMap.decode(text)
    local map = Json.decode(text)
    assert(type(map) == 'table' and Json.isArray(map.sources) and Json.isArray(map.names) and
        (map.sourcesContent == nil or Json.isArray(map.sourcesContent)),
        'Invalid source map: sources, names and sourcesContent must be JSON arrays')
    return validate(map)
end

function SourceMap.lookup(map, generatedLine)
    if not cache[map] then validate(map) end
    return cache[map][generatedLine]
end

return SourceMap

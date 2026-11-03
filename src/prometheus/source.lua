-- Source provenance is separate from binding/scope metadata.
local Ast = require('prometheus.ast')
local Source = {}
local counters = {}

function Source.new(path, content, internal)
    return {path = path or 'Anonymous Script', content = content, internal = internal == true}
end

function Source.internal(label, content)
    label = label or 'snippet'
    counters[label] = (counters[label] or 0) + 1
    return Source.new('prometheus-internal://' .. label .. '/' .. counters[label], content, true)
end

function Source.generated(label)
    local source = Source.internal(label, '-- Generated ' .. label .. ' code\n')
    return {source = source, startLine = 1, startColumn = 1, endLine = 1,
        endColumn = 1, startOffset = 0, endOffset = 0}
end

local fields = {'body', 'statements', 'lhs', 'rhs', 'args', 'expressions', 'entries',
    'key', 'value', 'base', 'index', 'condition', 'true_value', 'false_value',
    'elseifs', 'elsebody', 'initialValue', 'finalValue', 'incrementBy', 'target'}

-- Walk only syntax edges: symbols, scopes, loop backreferences and cached
-- analysis are intentionally excluded. Also descend through elseif records.
function Source.walk(root, callback)
    local seen = {}
    local function walk(node)
        if type(node) ~= 'table' or seen[node] then return end
        seen[node] = true
        if Ast.AstKind[node.kind] then callback(node) end
        for _, field in ipairs(fields) do walk(node[field]) end
        for _, child in ipairs(node) do walk(child) end
    end
    walk(root)
end

function Source.fill(node, span)
    if span then
        Source.walk(node, function(child)
            if not child.sourceSpan then child.sourceSpan = span end
        end)
    end
    return node
end

function Source.inherit(node, original)
    return Source.fill(node, original and original.sourceSpan)
end

function Source.sameLine(a, b)
    return a and b and a.source == b.source and a.startLine == b.startLine
end

return Source

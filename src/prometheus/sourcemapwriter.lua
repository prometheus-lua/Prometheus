-- Buffer provenance alongside the existing renderer, then emit whole tokens.
-- Private NUL-delimited tags never appear in output: Lua string values are
-- escaped before rendering and cannot collide with these annotations.
local Tokenizer = require('prometheus.tokenizer')
local Source = require('prometheus.source')
local SourceMap = require('prometheus.sourcemap')
local Writer = {}

function Writer.render(tagged, spans, luaVersion, includeSources)
    local parts, runs, stack = {}, {}, {}
    local cursor, offset = 1, 0
    local function append(text)
        if #text == 0 then return end
        parts[#parts + 1] = text
        runs[#runs + 1] = {start = offset, finish = offset + #text, span = stack[#stack]}
        offset = offset + #text
    end
    while true do
        local first, last, id = tagged:find('%z([^%z]*)%z', cursor)
        if not first then append(tagged:sub(cursor)); break end
        append(tagged:sub(cursor, first - 1))
        if id == '/' then
            assert(#stack > 0, 'Unbalanced source annotations')
            stack[#stack] = nil
        else
            local span = spans[tonumber(id)]
            assert(span, 'Invalid source annotation')
            stack[#stack + 1] = span
        end
        cursor = last + 1
    end
    assert(#stack == 0, 'Unbalanced source annotations')
    local text = table.concat(parts)
    local tokenizer = Tokenizer:new({LuaVersion = luaVersion, AllowInternalIdentifiers = true})
    tokenizer:append(text)
    local tokens = tokenizer:scanAll()
    local output, origins = {}, {}
    local line, runIndex, previousEnd, previousSpan, previousToken = 1, 1, 0, nil, nil
    local function emit(fragment, span)
        output[#output + 1] = fragment
        if span and #fragment > 0 and not fragment:match('^[ \t\r\n]*$') then
            origins[line] = origins[line] or span
        end
        for _ in fragment:gmatch('\n') do
            line = line + 1
            -- Actual multiline tokens retain their origin on continuation lines.
            if span then origins[line] = span end
        end
    end
    for _, token in ipairs(tokens) do
        if token.kind ~= Tokenizer.TokenKind.Eof then
            while runs[runIndex] and runs[runIndex].finish <= token.startPos do runIndex = runIndex + 1 end
            local span = runs[runIndex] and runs[runIndex].span
            -- Lua 5.1 rejects a newline between a callee and its argument '('.
            -- Attribute that delimiter to the callee; the call's closing
            -- delimiter still carries the enclosing operation's source line.
            if token.source == '(' and previousToken and
                (previousToken.kind == Tokenizer.TokenKind.Ident or previousToken.kind == Tokenizer.TokenKind.String or
                 previousToken.source == ')' or previousToken.source == ']' or previousToken.source == '}') then
                span = previousSpan
            end
            local gap = text:sub(previousEnd + 1, token.startPos)
            if previousSpan and span and not Source.sameLine(previousSpan, span) and not gap:find('\n', 1, true) then
                -- Keep pretty-print indentation; replace only inter-token spacing.
                gap = '\n' .. gap
            end
            emit(gap)
            emit(text:sub(token.startPos + 1, token.endPos), span)
            previousEnd, previousSpan, previousToken = token.endPos, span, token
        end
    end
    emit(text:sub(previousEnd + 1))
    return table.concat(output), SourceMap.build(origins, line, includeSources)
end

return Writer

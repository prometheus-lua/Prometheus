local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local SourceMap = Prometheus.SourceMap

local Parser = require('prometheus.parser')
local Source = require('prometheus.source')
local Tokenizer = require('prometheus.tokenizer')
local parser = Parser:new({LuaVersion = 'Lua51'})

local code = 'local x = a + 2 * (b - 3)\r\nreturn obj.foo(x, "hi")[1]'
local tree = parser:parse(code, 'precise.lua')
local nodes = {}
Source.walk(tree, function(node)
	local span = assert(node.sourceSpan, node.kind .. ' has no source span')
	assert(span.source.path == 'precise.lua')
	assert(span.source.content == code)
	assert(span.startOffset <= span.endOffset and span.endOffset <= #code)
	nodes[node.kind] = nodes[node.kind] or {}
	table.insert(nodes[node.kind], span)
end)

local function hasSpan(kind, startOffset, endOffset)
	for _, span in ipairs(nodes[kind] or {}) do
		if span.startOffset == startOffset and span.endOffset == endOffset then return true end
	end
	return false
end

assert(hasSpan('TopNode', 0, #code))
assert(hasSpan('Block', 0, #code))
assert(hasSpan('AddExpression', 10, 25))
assert(hasSpan('MulExpression', 14, 25))
assert(hasSpan('SubExpression', 18, 25))
assert(hasSpan('FunctionCallExpression', 34, 50))
assert(hasSpan('IndexExpression', 34, 53))

local semicolonTree = parser:parse('local x=nil;\nreturn x+1', 'semicolon-line.lua')
assert(semicolonTree.body.statements[2].sourceSpan.startLine == 2)
assert(semicolonTree.body.statements[2].sourceSpan.startColumn == 1)

local declarations = parser:parse('function f(arg, ...) return {name=arg, [1]=...} end', 'entries.lua')
local entries, args = 0, 0
Source.walk(declarations, function(node)
	assert(node.sourceSpan and node.sourceSpan.source.path == 'entries.lua')
	if node.kind == 'KeyedTableEntry' then entries = entries + 1 end
	if node.kind == 'VarargExpression' or (node.kind == 'VariableExpression' and node.sourceSpan.startOffset == 11) then
		args = args + 1
	end
end)
assert(entries == 2 and args >= 2, 'Table entries and parameters must have spans')

local internalA = parser:parse('')
local internalB = parser:parse('')
assert(internalA.sourceSpan.source.internal and internalB.sourceSpan.source.internal)
assert(internalA.sourceSpan.source.path ~= internalB.sourceSpan.source.path)
assert(internalA.sourceSpan.startOffset == 0 and internalA.sourceSpan.endOffset == 0)
local explicitRecord = Source.new('record.lua', 'return 2')
assert(parser:parse(explicitRecord.content, explicitRecord).sourceSpan.source == explicitRecord)

local tokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
tokenizer:append('a\r\nb')
local tokens = tokenizer:scanAll()
assert(tokens[1].line == 1 and tokens[1].linePos == 1)
assert(tokens[1].endLine == 1 and tokens[1].endLinePos == 2)
assert(tokens[1].startPos == 0 and tokens[1].endPos == 1)
assert(tokens[2].line == 2 and tokens[2].linePos == 1)
assert(tokens[2].endLine == 2 and tokens[2].endLinePos == 2)
assert(tokens[3].line == 2 and tokens[3].linePos == 2)
assert(tokens[3].endLine == 2 and tokens[3].endLinePos == 2)

local emptyTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
emptyTokenizer:append('')
local eof = emptyTokenizer:scanAll()[1]
assert(eof.startPos == 0 and eof.endPos == 0)
assert(eof.line == 1 and eof.linePos == 1 and eof.endLine == 1 and eof.endLinePos == 1)
local crlfTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
crlfTokenizer:append('\r\n')
local crlfEof = crlfTokenizer:scanAll()[1]
assert(crlfEof.line == 2 and crlfEof.linePos == 1)
assert(crlfEof.endLine == 2 and crlfEof.endLinePos == 1)
local pairedNewlines = {
	{'\r\n\r\n', 3},
	{'\n\r\n\r', 3},
	{'\r\n\n\r', 3},
	{'\n\r\r\n', 3},
}
for _, case in ipairs(pairedNewlines) do
	local newline, expectedLine = case[1], case[2]
	local pairedTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
	pairedTokenizer:append(newline)
	local pairedEof = pairedTokenizer:scanAll()[1]
	assert(pairedEof.line == expectedLine and pairedEof.linePos == 1)
	assert(pairedEof.endLine == expectedLine and pairedEof.endLinePos == 1)
end
local loadChunk = loadstring or load
for _, case in ipairs(pairedNewlines) do
	local newline, expectedLine = case[1], case[2]
	local input = 'local x={}' .. newline .. 'return x.missing + 1' .. newline
	local mappedAst = Parser:new({LuaVersion = 'Lua51'}):parse(input, 'paired-newlines.lua')
	assert(mappedAst.body.statements[2].sourceSpan.startLine == expectedLine)
	assert(mappedAst.sourceSpan.endLine == expectedLine + 2)
	for _, pretty in ipairs({false, true}) do
		local pipeline = Prometheus.Pipeline:fromConfig({LuaVersion = 'Lua51', Seed = 7,
			SourceMap = true, PrettyPrint = pretty, Steps = {}})
		local generated, map = pipeline:apply(input, 'paired-newlines.lua')
		local chunk = assert(loadChunk(generated, '@paired-output.lua'))
		local ok, err = pcall(chunk)
		assert(not ok, 'Paired newline source-map fixture must fail')
		local generatedLine = tonumber(tostring(err):match('paired%-output%.lua:(%d+):'))
		assert(generatedLine, tostring(err))
		local recovered = SourceMap.lookup(map, generatedLine)
		assert(recovered and recovered.source == 'paired-newlines.lua'
			and recovered.line == expectedLine,
			(pretty and 'Pretty' or 'Compact') .. ' map recovered '
				.. (recovered and recovered.source .. ':' .. recovered.line or 'no source'))
	end
end
for _, newline in ipairs({'\n\n', '\r\r'}) do
	local repeatedTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
	repeatedTokenizer:append('a' .. newline .. 'b')
	local repeatedTokens = repeatedTokenizer:scanAll()
	assert(repeatedTokens[2].line == 3 and repeatedTokens[2].linePos == 1)
end

-- Independently calculate coordinates at every byte boundary. Newline pairs
-- consume two opposite newline bytes as one line break; equal adjacent newline
-- bytes remain two separate line breaks.
local function referencePositions(text)
	local positions = {[0] = {line = 1, column = 1}}
	local line, column, offset = 1, 1, 0
	while offset < #text do
		local character = text:sub(offset + 1, offset + 1)
		if character == '\r' or character == '\n' then
			local nextCharacter = text:sub(offset + 2, offset + 2)
			local paired = (character == '\r' and nextCharacter == '\n')
				or (character == '\n' and nextCharacter == '\r')
			line, column = line + 1, 1
			positions[offset + 1] = {line = line, column = column}
			offset = offset + 1
			if paired then
				positions[offset + 1] = {line = line, column = column}
				offset = offset + 1
			end
		else
			column = column + 1
			offset = offset + 1
			positions[offset] = {line = line, column = column}
		end
	end
	return positions
end

local function assertAllBytePositions(tokenizer, text)
	local expected = referencePositions(text)
	for offset = 0, #text do
		local line, column = tokenizer:getPosition(offset)
		assert(line == expected[offset].line and column == expected[offset].column,
			string.format('Offset %d in %q expected %d:%d, got %d:%d', offset, text,
				expected[offset].line, expected[offset].column, line, column))
	end
	local eof = expected[#text]
	local line, column = tokenizer:getPosition(#text + 1)
	assert(line == eof.line and column == eof.column, 'Past-EOF position should fall back to EOF')
	line, column = tokenizer:getPosition(-1)
	assert(line == eof.line and column == eof.column, 'Negative position should fall back to EOF')
end

local coordinateSamples = {
	'ASCII byte columns',
	'one\r\ntwo\n\rthree\r\n\r\nend',
	'caf\195\169\r\nline\n\rend',
	'\r\n\r\n\n\r\n\r',
}
local coordinateTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
for _, sample in ipairs(coordinateSamples) do
	coordinateTokenizer:reset()
	coordinateTokenizer:append(sample)
	assertAllBytePositions(coordinateTokenizer, sample)
end

-- Appending may split a pair across calls; reset must also clear old coordinates.
coordinateTokenizer:reset()
coordinateTokenizer:append('prefix\r')
assertAllBytePositions(coordinateTokenizer, 'prefix\r')
coordinateTokenizer:append('\nnext\n\r')
assertAllBytePositions(coordinateTokenizer, 'prefix\r\nnext\n\r')
coordinateTokenizer:reset()
coordinateTokenizer:append('q')
assertAllBytePositions(coordinateTokenizer, 'q')

parser.disableLog = true
assert(not pcall(function() parser:parse('local =') end))
assert(parser.disableLog, 'parse should preserve the caller logging preference')
parser.disableLog = false
assert(parser:parse('return 1', 'after-error.lua').sourceSpan.source.path == 'after-error.lua')

print('Parser source span and tokenizer coordinate checks passed')

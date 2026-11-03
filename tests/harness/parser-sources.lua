local Prometheus = require('src.prometheus')
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error

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
local lfcrTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
lfcrTokenizer:append('a\n\rb')
local lfcrTokens = lfcrTokenizer:scanAll()
assert(lfcrTokens[2].line == 2 and lfcrTokens[2].linePos == 1)
for _, newline in ipairs({'\n\n', '\r\r'}) do
	local repeatedTokenizer = Tokenizer:new({LuaVersion = 'Lua51'})
	repeatedTokenizer:append('a' .. newline .. 'b')
	local repeatedTokens = repeatedTokenizer:scanAll()
	assert(repeatedTokens[2].line == 3 and repeatedTokens[2].linePos == 1)
end

parser.disableLog = true
assert(not pcall(function() parser:parse('local =') end))
assert(parser.disableLog, 'parse should preserve the caller logging preference')
parser.disableLog = false
assert(parser:parse('return 1', 'after-error.lua').sourceSpan.source.path == 'after-error.lua')

print('Parser source span and tokenizer coordinate checks passed')

require("src.prometheus") -- Sets the repository module path used by tokenizer dependencies.
local Tokenizer = require("prometheus.tokenizer")

local function check(body, expected)
	local source = "[=[" .. body .. "]=]"
	local tokenizer = Tokenizer:new({LuaVersion = "Lua51"})
	tokenizer:append(source)
	local token = tokenizer:next()
	assert(token.kind == Tokenizer.TokenKind.String)
	assert(token.value == expected, string.format("expected %q, got %q", expected, token.value))
	assert(token.startPos == 0 and token.endPos == #source, "token positions must use raw source bytes")
	assert(token.source == source, "token source must retain original newline bytes")
end

-- Lua drops one initial newline sequence, for every accepted line ending.
for _, newline in ipairs({"\n", "\r", "\r\n", "\n\r"}) do
	check(newline .. "body", "body")
end

-- Internal newline sequences normalize to LF; equal adjacent bytes stay distinct.
check("a\nb\rc\r\nd\n\re", "a\nb\nc\nd\ne")
check("a\r\rb\n\nc", "a\n\nb\n\nc")

-- A newline immediately before the closing delimiter is still part of the value.
for _, newline in ipairs({"\n", "\r", "\r\n", "\n\r"}) do
	check("body" .. newline, "body\n")
end

print("Long string newline normalization checks passed")

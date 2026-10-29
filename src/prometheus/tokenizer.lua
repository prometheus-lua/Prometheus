-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- tokenizer.lua
-- Overview:
-- This Script provides a class for lexical Analysis of lua code.
-- This Tokenizer is Capable of tokenizing LuaU and Lua5.1
local Enums = require("prometheus.enums");
local util = require("prometheus.util");
local logger = require("logger");
local config = require("config");

local LuaVersion = Enums.LuaVersion;
local lookupify = util.lookupify;
local unlookupify = util.unlookupify;
local escape = util.escape;
local chararray = util.chararray;
local keys = util.keys;
local Tokenizer = {};

Tokenizer.EOF_CHAR = "<EOF>";
Tokenizer.WHITESPACE_CHARS = lookupify{
	" ", "\t", "\n", "\r", "\v", "\f",
}

Tokenizer.ANNOTATION_CHARS = lookupify(chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"))
Tokenizer.ANNOTATION_START_CHARS = lookupify(chararray("!@"))

Tokenizer.Conventions = Enums.Conventions;

Tokenizer.TokenKind = {
	Eof = "Eof",
	Keyword = "Keyword",
	Symbol = "Symbol",
	Ident = "Identifier",
	Number = "Number",
	Integer = "Integer",
	String = "String",
	InterpolatedString = "InterpolatedString",
}

Tokenizer.EOF_TOKEN = {
	kind = Tokenizer.TokenKind.Eof,
	value = "<EOF>",
	startPos = -1,
	endPos = -1,
	source = "<EOF>",
}

local function token(self, startPos, kind, value)
	if kind ~= Tokenizer.TokenKind.Eof then self.hasTokens = true end
	local line, linePos = self:getPosition(self.index);
	local annotations = self.annotations
	self.annotations = {};
	return {
		kind = kind,
		value = value,
		startPos = startPos,
		endPos = self.index,
		source = self.source:sub(startPos + 1, self.index),
		line = line,
		linePos = linePos,
		annotations = annotations,
	}
end

local function generateError(self, message)
	local line, linePos = self:getPosition(self.index);
	return "Lexing Error at Position " .. tostring(line) .. ":" .. tostring(linePos) .. ", " .. message;
end

local function generateWarning(token, message)
	return "Warning at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
end

function Tokenizer:getPosition(i)
	i = math.max(1, i);
	local starts = self.lineStarts or {1};
	local first, last = 1, #starts;
	while first < last do
		local middle = math.floor((first + last + 1) / 2);
		if starts[middle] <= i then first = middle else last = middle - 1 end
	end
	return first, i - starts[first] + 1;
end

--// Prepare columnMap for getPosition
function Tokenizer:prepareGetPosition()
	local starts, index = {1}, 1;
	while index <= self.length do
		local char = self.source:sub(index, index);
		if char == "\n" or char == "\r" then
			local nextChar = self.source:sub(index + 1, index + 1);
			if (char == "\n" and nextChar == "\r") or (char == "\r" and nextChar == "\n") then index = index + 1 end
			starts[#starts + 1] = index + 1;
		end
		index = index + 1;
	end
	self.lineStarts = starts;
end

-- Constructor for Tokenizer
function Tokenizer:new(settings)
	local luaVersion = (settings and (settings.luaVersion or settings.LuaVersion)) or LuaVersion.LuaU;
	local conventions = Tokenizer.Conventions[luaVersion];

	if(conventions == nil) then
		logger:error("The Lua Version \"" .. luaVersion .. "\" is not recognized by the Tokenizer! Please use one of the following: \"" .. table.concat(keys(Tokenizer.Conventions), "\",\"") .. "\"");
	end

	local tokenizer = {
		index = 0, -- Index where the current char is read
		length = 0,
		source = "", -- Source to Tokenize
		luaVersion = luaVersion, -- LuaVersion to be used while Tokenizing
		allowInternalIdentifiers = settings and settings.AllowInternalIdentifiers == true,
		conventions = conventions;

		NumberChars = conventions.NumberChars,
		NumberCharsLookup = lookupify(conventions.NumberChars),
		Keywords = conventions.Keywords,
		KeywordsLookup = lookupify(conventions.Keywords),
		HybridKeywordsLookup = lookupify(conventions.HybridKeywords or {}),
		BinaryNumberChars = conventions.BinaryNumberChars,
		BinaryNumberCharsLookup = lookupify(conventions.BinaryNumberChars);
		BinaryNums = conventions.BinaryNums,
		HexadecimalNums = conventions.HexadecimalNums,
		HexNumberChars = conventions.HexNumberChars,
		HexNumberCharsLookup = lookupify(conventions.HexNumberChars),
		DecimalExponent = conventions.DecimalExponent,
		DecimalSeperators = conventions.DecimalSeperators,
		IdentChars = conventions.IdentChars,
		IdentCharsLookup = lookupify(conventions.IdentChars),

		EscapeSequences = conventions.EscapeSequences,
		NumericalEscapes = conventions.NumericalEscapes,
		EscapeZIgnoreNextWhitespace = conventions.EscapeZIgnoreNextWhitespace,
		HexEscapes = conventions.HexEscapes,
		UnicodeEscapes = conventions.UnicodeEscapes,

		SymbolChars = conventions.SymbolChars,
		SymbolCharsLookup = lookupify(conventions.SymbolChars),
		MaxSymbolLength = conventions.MaxSymbolLength,
		Symbols = conventions.Symbols,
		SymbolsLookup = lookupify(conventions.Symbols),

		StringStartLookup = lookupify({"\"", "\'"}),
		annotations = {},
	};

	setmetatable(tokenizer, self);
	self.__index = self;

	return tokenizer;
end

-- Reset State of Tokenizer to Tokenize another File
function Tokenizer:reset()
	self.index = 0;
	self.length = 0;
	self.source = "";
	self.annotations = {};
	self.lineStarts = {1};
	self.hasTokens = false;
	self.directives = {};
end

-- Append String to this Tokenizer
function Tokenizer:append(code)
	self.source = self.source .. code
	self.length = self.length + code:len();
	self:prepareGetPosition();
end

-- Function to peek the n'th char in the source of the tokenizer
local function peek(self, n)
	n = n or 0;
	local i = self.index + n + 1;
	if i > self.length then
		return Tokenizer.EOF_CHAR
	end
	return self.source:sub(i, i);
end

-- Function to get the next char in the source
local function get(self)
	local i = self.index + 1;
	if i > self.length then
		logger:error(generateError(self, "Unexpected end of Input"));
	end
	self.index = self.index + 1;
	return self.source:sub(i, i);
end

-- The same as get except it throws an Error if the char is not contained in charOrLookup
local function expect(self, charOrLookup)
	if(type(charOrLookup) == "string") then
		charOrLookup = {[charOrLookup] = true};
	end

	local char = peek(self);
	if charOrLookup[char] ~= true then
		local etb = unlookupify(charOrLookup);
		for i, v in ipairs(etb) do
			etb[i] = escape(v);
		end
		local errorMessage = "Unexpected char \"" .. escape(char) .. "\"! Expected one of \"" .. table.concat(etb, "\",\"") .. "\"";
		logger:error(generateError(self, errorMessage));
	end

	self.index = self.index + 1;
	return char;
end

-- Returns wether the n'th char is in the lookup
local function is(self, charOrLookup, n)
	local char = peek(self, n);
	if(type(charOrLookup) == "string") then
		return char == charOrLookup;
	end
	return charOrLookup[char];
end

function Tokenizer:parseAnnotation()
	if is(self, Tokenizer.ANNOTATION_START_CHARS) then
		self.index = self.index + 1;
		local source, length = {}, 0;
		while(is(self, Tokenizer.ANNOTATION_CHARS)) do
			source[length + 1] = get(self)
			length = #source
		end
		if length > 0 then
			self.annotations[string.lower(table.concat(source))] = true;
		end
		return nil;
	end
	return get(self);
end

-- skip one or 0 Comments and return wether one was found
function Tokenizer:skipComment()
	if(is(self, "-", 0) and is(self, "-", 1)) then
		local commentStart = self.index;
		self.index = self.index + 2;
		if(is(self, "[")) then
			self.index = self.index + 1;
			local eqCount = 0;
			while(is(self, "=")) do
				self.index = self.index + 1;
				eqCount = eqCount + 1;
			end
			if(is(self, "[")) then
				-- Multiline Comment
				-- Get all Chars to Closing bracket but also consider that the count of equal signs must be the same
				while true do
					if(self:parseAnnotation() == ']') then
						local eqCount2 = 0;
						while(is(self, "=")) do
							self.index = self.index + 1;
							eqCount2 = eqCount2 + 1;
						end
						if(is(self, "]")) then
							if(eqCount2 == eqCount) then
								self.index = self.index + 1;
								return true
							end
						end
					end
				end
			end
		end
		-- Single Line Comment
		-- Get all Chars to next Newline
		while self.index < self.length and not is(self, "\n") and not is(self, "\r") do self:parseAnnotation() end
		if not self.hasTokens then
			local comment = self.source:sub(commentStart + 1, self.index);
			if comment:match("^%-%-!native%s*$") or comment:match("^%-%-!optimize%s+[012]%s*$") then
				self.directives = self.directives or {};
				self.directives[#self.directives + 1] = comment;
			end
		end
		return true;
	end
	return false;
end

-- skip All Whitespace and Comments to next Token
function Tokenizer:skipWhitespaceAndComments()
	while self:skipComment() do end
	while is(self, Tokenizer.WHITESPACE_CHARS) do
		self.index = self.index + 1;
		while self:skipComment() do end
	end
end

local function int(self, chars, seperators)
	local buffer = {};
	while true do
		if (is(self, chars)) then
			buffer[#buffer + 1] = get(self)
		elseif (is(self, seperators)) then
			self.index = self.index + 1;
		else
			break
		end
	end
	return table.concat(buffer);
end

-- Parse radix integers without depending on the host's integer width or rounding
-- at every digit. Luau saturates overflowing radix literals at UINT64_MAX.
local function radixNumber(source, base)
	local high, low = 0, 0;
	for i = 1, #source do
		local digit = tonumber(source:sub(i, i), base);
		local nextLow = low * base + digit;
		high = high * base + math.floor(nextLow / 4294967296);
		low = nextLow % 4294967296;
		if high >= 4294967296 then return 18446744073709551616 end
	end
	return high * 4294967296.0 + low;
end

function Tokenizer:luauNumber()
	local startPos = self.index;
	if is(self, ".") then self.index = self.index + 1 end
	-- Match Luau's entire number-like token before validating its value. In
	-- particular, 1foo and 1..2 must not split into otherwise valid tokens.
	repeat
		self.index = self.index + 1;
	until not (is(self, self.NumberCharsLookup) or is(self, ".") or is(self, "_"))
	if is(self, "e") or is(self, "E") then
		self.index = self.index + 1;
		if is(self, "+") or is(self, "-") then self.index = self.index + 1 end
	end
	while is(self, self.IdentCharsLookup) do self.index = self.index + 1 end

	local source = self.source:sub(startPos + 1, self.index):gsub("_", "");
	local prefix = source:sub(1, 2):lower();
	if source:sub(-1) == "i" then
		local digits = source:sub(1, -2);
		-- Radix integer literals are unsigned bit patterns; decimals are signed.
		local valid;
		if prefix == "0x" then
			digits = source:sub(3, -2);
			valid = digits:match("^[0-9a-fA-F]+$") and #digits:gsub("^0+", "") <= 16;
		elseif prefix == "0b" then
			digits = source:sub(3, -2);
			valid = digits:match("^[01]+$") and #digits:gsub("^0+", "") <= 64;
		else
			local significant = digits:gsub("^0+", "");
			valid = digits:match("^%d+$") and (#significant < 19 or (#significant == 19 and significant <= "9223372036854775807"));
		end
		if not valid then logger:error(generateError(self, "Malformed or overflowing integer '" .. source .. "'")) end
		return token(self, startPos, Tokenizer.TokenKind.Integer, source);
	end
	local value;
	if prefix == "0x" or prefix == "0b" then
		local digits = source:sub(3);
		local pattern = prefix == "0x" and "^[0-9a-fA-F]+$" or "^[01]+$";
		if digits:match(pattern) then value = radixNumber(digits, prefix == "0x" and 16 or 2) end
	else
		local mantissa = source;
		if source:find("[eE]") then
			mantissa = source:match("^(.-)[eE][+-]?%d+$");
		end
		if mantissa and (mantissa:match("^%d+%.?%d*$") or mantissa:match("^%.%d+$")) then
			value = tonumber(source);
		end
	end
	if value == nil then
		logger:error(generateError(self, "Malformed number '" .. self.source:sub(startPos + 1, self.index) .. "'"));
	end
	return token(self, startPos, Tokenizer.TokenKind.Number, value);
end

-- Lex the next token as a Number
function Tokenizer:number()
	if self.luaVersion == LuaVersion.LuaU then return self:luauNumber() end
	local startPos = self.index;
	local source = expect(self, setmetatable({["."] = true}, {__index = self.NumberCharsLookup}));

	if source == "0" then
		if self.BinaryNums and is(self, lookupify(self.BinaryNums)) then
			self.index = self.index + 1;
			source = int(self, self.BinaryNumberCharsLookup, lookupify(self.DecimalSeperators or {}));
			local value = tonumber(source, 2);
			return token(self, startPos, Tokenizer.TokenKind.Number, value);
		end

		if self.HexadecimalNums and is(self, lookupify(self.HexadecimalNums)) then
			self.index = self.index + 1;
			source = int(self, self.HexNumberCharsLookup, lookupify(self.DecimalSeperators or {}));
			local value = tonumber(source, 16);
			return token(self, startPos, Tokenizer.TokenKind.Number, value);
		end
	end

	if source == "." then
		source = source .. int(self, self.NumberCharsLookup, lookupify(self.DecimalSeperators or {}));
	else
		source = source .. int(self, self.NumberCharsLookup, lookupify(self.DecimalSeperators or {}));
		if(is(self, ".")) then
			source = source .. get(self) .. int(self, self.NumberCharsLookup, lookupify(self.DecimalSeperators or {}));
		end
	end

	if(self.DecimalExponent and is(self, lookupify(self.DecimalExponent))) then
		source = source .. get(self);
		if(is(self, lookupify({"+","-"}))) then
			source = source .. get(self);
		end
		local v = int(self, self.NumberCharsLookup, lookupify(self.DecimalSeperators or {}));
		if(v:len() < 1) then
			logger:error(generateError(self, "Expected a Valid Exponent!"));
		end
		source = source .. v;
	end

	local value = tonumber(source);
	return token(self, startPos, Tokenizer.TokenKind.Number, value);
end

-- Lex the Next Token as Identifier or Keyword
function Tokenizer:ident()
	local startPos = self.index;
	local source = expect(self, self.IdentCharsLookup)
	local sourceAddContent = {source}
	while(is(self, self.IdentCharsLookup)) do
		-- source = source .. get(self);
		table.insert(sourceAddContent, get(self))
	end
	source = table.concat(sourceAddContent)
	if(self.KeywordsLookup[source]) then
		return token(self, startPos, Tokenizer.TokenKind.Keyword, source);
	end

	local tk = token(self, startPos, Tokenizer.TokenKind.Ident, source);
	-- Contextual keywords remain identifiers until the parser sees a declaration
	-- or a bare continue statement; they are legal names everywhere else.
	tk.isHybridKeyword = self.HybridKeywordsLookup[source] == true;

	if(not self.allowInternalIdentifiers
		and string.sub(source, 1, string.len(config.IdentPrefix)) == config.IdentPrefix) then
		logger:warn(generateWarning(tk, string.format("identifiers should not start with \"%s\" as this may break the program", config.IdentPrefix)));
	end

	return tk;
end

function Tokenizer:singleLineString()
	local startPos = self.index;
	local startChar = expect(self, self.StringStartLookup);
	local buffer = {};

	while (not is(self, startChar)) do
		local char = get(self);

		-- Single Line String may not contain Linebreaks except when they are escaped by \
		if(char == '\n' or char == '\r') then
			self.index = self.index - 1;
			logger:error(generateError(self, "Unterminated String"));
		end


		if(char == "\\") then
			char = get(self);

			local escape = self.EscapeSequences[char];
			if(type(escape) == "string") then
				char = escape;

			elseif(self.NumericalEscapes and self.NumberCharsLookup[char]) then
				local numstr = char;

				if(is(self, self.NumberCharsLookup)) then
					char = get(self);
					numstr = numstr .. char;
				end

				if(is(self, self.NumberCharsLookup)) then
					char = get(self);
					numstr = numstr .. char;
				end

				local value = tonumber(numstr);
				if value > 255 then logger:error(generateError(self, "Decimal escape exceeds 255")) end
				char = string.char(value);

			elseif(self.UnicodeEscapes and char == "u") then
				expect(self, "{");
				local num = "";
				while (is(self, self.HexNumberCharsLookup)) do
					num = num .. get(self);
				end
				expect(self, "}");
				local value = tonumber(num, 16);
				if not value or value > 0x10ffff then logger:error(generateError(self, "Invalid Unicode escape")) end
				char = util.utf8char(value);
			elseif(self.HexEscapes and char == "x") then
				local hex = expect(self, self.HexNumberCharsLookup) .. expect(self, self.HexNumberCharsLookup);
				char = string.char(tonumber(hex, 16));
			elseif(self.EscapeZIgnoreNextWhitespace and char == "z") then
				char = "";
				while(is(self, Tokenizer.WHITESPACE_CHARS)) do
					self.index = self.index + 1;
				end
			elseif char == "\n" or char == "\r" then
				local nextChar = peek(self);
				if (char == "\r" and nextChar == "\n") or (self.luaVersion == LuaVersion.Lua51 and char == "\n" and nextChar == "\r") then
					self.index = self.index + 1;
				end
				char = "\n";
			end
		end

		--// since table.insert is slower in lua51
		buffer[#buffer + 1] = char
	end

	expect(self, startChar);

	return token(self, startPos, Tokenizer.TokenKind.String, table.concat(buffer))
end

-- Scan interpolation expressions with the regular lexer, including nested
-- strings, comments, table constructors, and interpolated strings.
function Tokenizer:interpolatedString()
	local startPos = self.index;
	expect(self, "`");
	local parts, literal = {}, {};
	local function flush()
		if #literal > 0 then
			parts[#parts + 1] = {literal = table.concat(literal)};
			literal = {};
		end
	end
	local function escapedCharacter()
		local char = get(self);
		local escape = self.EscapeSequences[char];
		if type(escape) == "string" then return escape end
		if self.NumericalEscapes and self.NumberCharsLookup[char] then
			local digits = char;
			for _ = 1, 2 do
				if is(self, self.NumberCharsLookup) then digits = digits .. get(self) else break end
			end
			local value = tonumber(digits);
			if value > 255 then logger:error(generateError(self, "Decimal escape exceeds 255")) end
			return string.char(value);
		end
		if self.UnicodeEscapes and char == "u" then
			expect(self, "{");
			local hex = "";
			while is(self, self.HexNumberCharsLookup) do hex = hex .. get(self) end
			expect(self, "}");
			local value = tonumber(hex, 16);
			if not value or value > 0x10ffff then
				logger:error(generateError(self, "Invalid Unicode escape"));
			end
			return util.utf8char(value);
		end
		if self.HexEscapes and char == "x" then
			return string.char(tonumber(expect(self, self.HexNumberCharsLookup) .. expect(self, self.HexNumberCharsLookup), 16));
		end
		if self.EscapeZIgnoreNextWhitespace and char == "z" then
			while is(self, Tokenizer.WHITESPACE_CHARS) do self.index = self.index + 1 end
			return "";
		end
		if char == "\n" or char == "\r" then
			local nextChar = peek(self);
			if char == "\r" and nextChar == "\n" then
				self.index = self.index + 1;
			end
			return "\n";
		end
		return char;
	end

	while self.index < self.length do
		local char = get(self);
		if char == "`" then
			flush();
			return token(self, startPos, Tokenizer.TokenKind.InterpolatedString, parts);
		elseif char == "\n" or char == "\r" then
			logger:error(generateError(self, "Unterminated interpolated string"));
		elseif char == "\\" then
			literal[#literal + 1] = escapedCharacter();
		elseif char == "{" then
			if is(self, "{") then
				logger:error(generateError(self, "Escape a literal '{' as \\{ in an interpolated string"));
			end
			flush();
			local tokens, depth = {}, 1;
			while depth > 0 do
				local tk = self:next();
				if tk.kind == Tokenizer.TokenKind.Eof then
					logger:error(generateError(self, "Expected '}' to close interpolation"));
				end
				if tk.kind == Tokenizer.TokenKind.Symbol then
					if tk.source == "{" then depth = depth + 1 end
					if tk.source == "}" then depth = depth - 1 end
				end
				if depth > 0 then
					tokens[#tokens + 1] = tk;
				else
					tokens[#tokens + 1] = {
						kind = Tokenizer.TokenKind.Eof, source = "", value = "<EOF>",
						line = tk.line, linePos = tk.linePos,
					};
				end
			end
			parts[#parts + 1] = {tokens = tokens};
		else
			literal[#literal + 1] = char;
		end
	end
	logger:error(generateError(self, "Unterminated interpolated string"));
end

function Tokenizer:multiLineString()
	local startPos = self.index;
	if(is(self, "[")) then
		self.index = self.index + 1;
		local eqCount = 0;
		while(is(self, "=")) do
			self.index = self.index + 1;
			eqCount = eqCount + 1;
		end
		if(is(self, "[")) then
			-- Multiline String
			-- Parse String to Closing bracket but also consider that the count of equal signs must be the same

			-- Lua normalizes CR, LF, CRLF, and LFCR line breaks to LF in long strings.
			local function normalizedNewline(char)
				local nextChar = peek(self)
				if (char == "\r" and nextChar == "\n") or (char == "\n" and nextChar == "\r") then
					self.index = self.index + 1
				end
				return "\n"
			end

			-- Skip one leading newline sequence, if present.
			self.index = self.index + 1;
			if(is(self, "\n") or is(self, "\r")) then
				normalizedNewline(get(self))
			end

			local value = "";
			while true do
				local char = get(self);
				if char == "\n" or char == "\r" then
					char = normalizedNewline(char)
				end
				if(char == ']') then
					local eqCount2 = 0;
					while(is(self, "=")) do
						char = char .. get(self);
						eqCount2 = eqCount2 + 1;
					end
					if(is(self, "]")) then
						if(eqCount2 == eqCount) then
							self.index = self.index + 1;
							return token(self, startPos, Tokenizer.TokenKind.String, value), true
						end
					end
				end
				value = value .. char;
			end
		end
	end
	self.index = startPos;
	return nil, false -- There was not an actual multiline string at the given Position
end

function Tokenizer:symbol()
	local startPos = self.index;
	for len = self.MaxSymbolLength, 1, -1 do
		local str = self.source:sub(self.index + 1, self.index + len);
		if self.SymbolsLookup[str] then
			self.index = self.index + len;
			return token(self, startPos, Tokenizer.TokenKind.Symbol, str);
		end
	end
	logger:error(generateError(self, "Unknown Symbol"));
end


-- get the Next token
function Tokenizer:next()
	-- Skip All Whitespace before the token
	self:skipWhitespaceAndComments();

	local startPos = self.index;
	if startPos >= self.length then
		return token(self, startPos, Tokenizer.TokenKind.Eof);
	end

	-- Numbers
	if(is(self, self.NumberCharsLookup)) then
		return self:number();
	end

	-- Identifiers and Keywords
	if(is(self, self.IdentCharsLookup)) then
		return self:ident();
	end

	-- Backtick strings are only available in Luau.
	if(self.luaVersion == LuaVersion.LuaU and is(self, "`")) then
		return self:interpolatedString();
	end

	-- Singleline String Literals
	if(is(self, self.StringStartLookup)) then
		return self:singleLineString();
	end

	-- Multiline String Literals
	if(is(self, "[", 0)) then
		-- The isString variable is due to the fact that "[" could also be a symbol for indexing
		local value, isString = self:multiLineString();
		if isString then
			return value;
		end
	end

	-- Number starting with dot
	if(is(self, ".") and is(self, self.NumberCharsLookup, 1)) then
		return self:number();
	end

	-- Symbols
	if(is(self, self.SymbolCharsLookup)) then
		return self:symbol();
	end


	logger:error(generateError(self, "Unexpected char \"" .. escape(peek(self)) .. "\"!"));
end

function Tokenizer:scanAll()
	local tb = {};
	repeat
		local token = self:next();
		table.insert(tb, token);
	until token.kind == Tokenizer.TokenKind.Eof
	return tb
end

return Tokenizer

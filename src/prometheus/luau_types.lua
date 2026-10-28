-- Validate Luau's type grammar before erasing compile-time syntax.
-- Types, packs, generic declarations, and generic arguments have distinct rules.
-- Reference: luau-lang/luau Ast/src/Parser.cpp (parseType and related routines).
local Scope = require('prometheus.scope')
local logger = require('logger')

return function(Parser, token, is, consume, expect, peek, get)
	local S, I, K = token.Symbol, token.Ident, token.Keyword
	local TYPE = {kind = 'type'}
	local parseType, parseSimpleType, parseTypeSuffix, parseReturnType
	local parseGenerics, parseTypeArguments

	local function fail(self, message)
		local tk = peek(self)
		local diagnostic = string.format('Parsing Error at Position %s:%s, %s',
			tostring(tk.line or '?'), tostring(tk.linePos or '?'), message)
		if self.disableLog then error(diagnostic, 0) end
		logger:error(diagnostic)
	end

	local function startsPack(self)
		return is(self, S, '...') or (is(self, I) and is(self, S, '...', 1))
	end

	local function typeFollows(self)
		return is(self, S, '?') or is(self, S, '|') or is(self, S, '&')
	end

	local function parsePack(self)
		if consume(self, S, '...') then
			parseType(self)
		else
			expect(self, I)
			expect(self, S, '...')
		end
		return {kind = 'pack'}
	end

	-- A pack is a tail: it cannot be followed by another element in a type list.
	local function parseTypeList(self)
		local result = {kind = 'pack', count = 0, tail = false, named = false}
		if is(self, S, ')') then return result end
		repeat
			if startsPack(self) then
				parsePack(self)
				result.tail = true
				return result
			end
			if is(self, I) and is(self, S, ':', 1) then
				get(self)
				get(self)
				result.named = true
			end
			parseType(self)
			result.count = result.count + 1
		until not consume(self, S, ',')
		return result
	end

	local function parseFunctionTail(self)
		expect(self, S, '->')
		parseReturnType(self)
		return TYPE
	end

	local function parseParenthesized(self, allowPack)
		local generic = is(self, S, '<')
		if generic then parseGenerics(self, false) end
		expect(self, S, '(')
		local list = parseTypeList(self)
		expect(self, S, ')')
		if generic or list.named or is(self, S, '->') or is(self, S, ':') then
			return parseFunctionTail(self)
		end
		if allowPack then return list end
		if list.count == 1 and not list.tail then return TYPE end
		fail(self, "Expected '->' after function parameter types; a type pack is not a single type")
	end

	parseReturnType = function(self)
		if startsPack(self) then return parsePack(self) end
		if not consume(self, S, '(') then
			parseType(self)
			return {kind = 'pack', count = 1}
		end
		local list = parseTypeList(self)
		expect(self, S, ')')
		if list.named or is(self, S, '->') or is(self, S, ':') then
			parseFunctionTail(self)
			return {kind = 'pack', count = 1}
		end
		-- A single parenthesized return type can have union/optional suffixes.
		if list.count == 1 then parseTypeSuffix(self, TYPE) end
		return list
	end

	local function parseTable(self)
		expect(self, S, '{')
		local properties, indexer = 0, false
		while not consume(self, S, '}') do
			if (is(self, I, 'read') or is(self, I, 'write')) and not is(self, S, ':', 1) then
				get(self)
			end
			if consume(self, S, '[') then
				if is(self, token.String) and is(self, S, ']', 1) then
					local name = get(self)
					if name.value:find('\0', 1, true) then fail(self, 'A table type property cannot contain a null byte') end
					properties = properties + 1
				else
					if indexer then fail(self, 'A table type cannot contain more than one indexer') end
					parseType(self)
					indexer = true
				end
				expect(self, S, ']')
				expect(self, S, ':')
				parseType(self)
			elseif properties == 0 and not indexer and not (is(self, I) and is(self, S, ':', 1)) then
				-- Array shorthand is exactly {Type}, not a list of table fields.
				parseType(self)
				expect(self, S, '}')
				return TYPE
			else
				expect(self, I)
				expect(self, S, ':')
				parseType(self)
				properties = properties + 1
			end
			if not consume(self, S, ',') and not consume(self, S, ';') then
				expect(self, S, '}')
				return TYPE
			end
		end
		return TYPE
	end

	parseSimpleType = function(self, allowPack)
		if is(self, S, '(') or is(self, S, '<') then
			return parseParenthesized(self, allowPack)
		elseif is(self, S, '{') then
			return parseTable(self)
		elseif is(self, token.String) or is(self, K, 'nil') or is(self, K, 'true') or is(self, K, 'false') then
			get(self)
			return TYPE
		elseif is(self, I) then
			local name = get(self)
			if consume(self, S, '.') then
				expect(self, I)
			elseif name.value == 'typeof' then
				expect(self, S, '(')
				-- Parse the real expression grammar in a detached scope. It is never
				-- evaluated or added to the runtime AST and its reference graph.
				self:expression(Scope:new(Scope:newGlobal()))
				expect(self, S, ')')
				return TYPE
			end
			if is(self, S, '...') then fail(self, 'A type pack is not allowed in this type position') end
			if is(self, S, '<') then parseTypeArguments(self) end
			return TYPE
		end
		fail(self, 'Expected a type, got ' .. tostring(peek(self).source))
	end

	parseTypeSuffix = function(self, initial)
		local union, intersection = false, false
		local hasType = initial ~= nil
		while true do
			if consume(self, S, '|') then
				parseSimpleType(self, false)
				union, hasType = true, true
			elseif consume(self, S, '&') then
				parseSimpleType(self, false)
				intersection, hasType = true, true
			elseif consume(self, S, '?') then
				if not hasType then fail(self, "Expected a type before '?'") end
				union = true
			elseif is(self, S, '...') then
				fail(self, "Unexpected '...' after a type")
			else
				break
			end
			if union and intersection then
				fail(self, 'Mixing union and intersection types requires parentheses')
			end
		end
		return TYPE
	end

	parseType = function(self)
		local initial
		if not is(self, S, '|') and not is(self, S, '&') then initial = parseSimpleType(self, false) end
		return parseTypeSuffix(self, initial)
	end

	local function parseTypeOrPack(self)
		if startsPack(self) then return parsePack(self) end
		if is(self, S, '(') then
			local result = parseSimpleType(self, true)
			if result.kind == 'pack' then
				if result.count == 1 and not result.tail and typeFollows(self) then
					return parseTypeSuffix(self, TYPE)
				end
				return result
			end
			return parseTypeSuffix(self, result)
		end
		return parseType(self)
	end

	parseTypeArguments = function(self)
		expect(self, S, '<')
		if consume(self, S, '>') then return end
		repeat
			parseTypeOrPack(self)
		until not consume(self, S, ',')
		expect(self, S, '>')
	end

	parseGenerics = function(self, defaultsAllowed)
		if not consume(self, S, '<') then return false end
		local seenPack, seenDefault = false, false
		repeat
			expect(self, I)
			local pack = consume(self, S, '...')
			if seenPack and not pack then fail(self, 'Generic types must precede generic type packs') end
			seenPack = seenPack or pack
			if consume(self, S, '=') then
				if not defaultsAllowed then fail(self, 'Generic defaults are only allowed in type aliases') end
				seenDefault = true
				if pack then
					local result = parseTypeOrPack(self)
					if result.kind ~= 'pack' then fail(self, 'Expected a type pack as the generic default') end
				else
					parseType(self)
				end
			elseif seenDefault then
				fail(self, 'A generic parameter after a default must also have a default')
			end
		until not consume(self, S, ',')
		expect(self, S, '>')
		return true
	end

	function Parser:parseLuauTypeAnnotation()
		if self.luaVersion == 'LuaU' and consume(self, S, ':') then
			parseType(self)
			return true
		end
		return false
	end

	function Parser:parseLuauReturnAnnotation()
		if self.luaVersion == 'LuaU' and consume(self, S, ':') then
			parseReturnType(self)
			return true
		end
		return false
	end

	function Parser:parseLuauVarargAnnotation()
		if self.luaVersion == 'LuaU' and consume(self, S, ':') then
			if is(self, I) and is(self, S, '...', 1) then parsePack(self) else parseType(self) end
			return true
		end
		return false
	end

	function Parser:parseLuauGenerics()
		if self.luaVersion == 'LuaU' then return parseGenerics(self, false) end
		return false
	end

	function Parser:parseLuauCast()
		if self.luaVersion == 'LuaU' and consume(self, S, '::') then
			parseType(self)
			return true
		end
		return false
	end

	function Parser:parseLuauDeclaration()
		if self.luaVersion ~= 'LuaU' then return false end
		local offset = is(self, I, 'export') and 1 or 0
		if not is(self, I, 'type', offset) then return false end
		if not is(self, I, nil, offset + 1) and not is(self, K, 'function', offset + 1) then return false end
		if offset == 1 then get(self) end
		get(self)
		if consume(self, K, 'function') then
			expect(self, I)
			parseGenerics(self, false)
			expect(self, S, '(')
			local scope = Scope:new(Scope:newGlobal())
			self:functionArgList(scope)
			expect(self, S, ')')
			self:parseLuauReturnAnnotation()
			self:block(nil, false, scope)
			expect(self, K, 'end')
		else
			expect(self, I)
			parseGenerics(self, true)
			expect(self, S, '=')
			parseType(self)
		end
		return true
	end
end

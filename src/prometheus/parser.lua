-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- parser.lua
-- Overview:
-- This Script provides a class for parsing of lua code.
-- This Parser is Capable of parsing LuaU and Lua5.1
--
-- Note that when parsing LuaU "continue" is treated as a Keyword, so no variable may be named "continue" even though this would be valid in LuaU
--
-- Settings Object:
-- luaVersion : The LuaVersion of the Script - Currently Supported : Lua51 and LuaU
-- AllowInternalIdentifiers : Skip reserved-prefix warnings for generated code (default false)
--

local Tokenizer = require("prometheus.tokenizer");
local Enums = require("prometheus.enums");
local util = require("prometheus.util");
local Ast = require("prometheus.ast");
local analyzeBindings = require("prometheus.bindinganalysis");
local logger = require("logger");
local Source = require("prometheus.source");

local AstKind = Ast.AstKind;

local LuaVersion = Enums.LuaVersion;
local lookupify = util.lookupify;

local TokenKind = Tokenizer.TokenKind;
local unpack = unpack or table.unpack

-- Transient parser name environments never become part of the AST.
local Bindings = {};
Bindings.__index = Bindings;
function Bindings:new(parent)
	return setmetatable({parent = parent, names = {}}, self);
end
function Bindings:create(name, token)
	if self.names[name] and token then
		logger:warn("Warning at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos)
			.. ', the variable "' .. name .. '" is already defined in that scope');
	end
	return Ast.LocalSymbol(name);
end
function Bindings:enable(symbol)
	self.names[symbol.name] = symbol;
end
function Bindings:declare(name, token)
	local symbol = self:create(name, token);
	self:enable(symbol);
	return symbol;
end
function Bindings:resolve(name)
	local symbol = self.names[name];
	if not symbol and self.parent then return self.parent:resolve(name); end
	return symbol and Ast.VariableExpression(symbol) or Ast.GlobalVariableExpression(name);
end

local Parser = {};

local ASSIGNMENT_NO_WARN_LOOKUP = lookupify{
	AstKind.NilExpression,
	AstKind.FunctionCallExpression,
	AstKind.PassSelfFunctionCallExpression,
	AstKind.VarargExpression
};

local CALLABLE_PREFIX_EXPRESSION_LOOKUP = lookupify{
	AstKind.VariableExpression,
	AstKind.GlobalVariableExpression,
	AstKind.IndexExpression,
	AstKind.FunctionCallExpression,
	AstKind.PassSelfFunctionCallExpression
};

local function generateError(self, message)
	local token;
	if(self.index > self.length) then
		token = self.tokens[self.length];
	elseif(self.index < 1) then
		return "Parsing Error at Position 0:0, " .. message;
	else
		token = self.tokens[self.index];
	end

	return "Parsing Error at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
end

local function generateWarning(token, message)
	return "Warning at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
end

local function sourceSpan(self, startOffset, endOffset)
	local startLine, startColumn = self.tokenizer:getPosition(startOffset)
	local endLine, endColumn = self.tokenizer:getPosition(endOffset)
	return {
		source = self.sourceRecord,
		startLine = startLine,
		startColumn = startColumn,
		endLine = endLine,
		endColumn = endColumn,
		startOffset = startOffset,
		endOffset = endOffset,
	}
end

local function tokenSpan(self, token)
	if token then return sourceSpan(self, token.startPos, token.endPos) end
end

local function parserRangeSpan(self, firstIndex, lastIndex)
	local first = self.tokens[firstIndex]
	local last = self.tokens[lastIndex]
	local startOffset = first and first.startPos or self.tokenizer.length
	local endOffset = last and last.endPos or startOffset
	if lastIndex < firstIndex then endOffset = startOffset end
	return sourceSpan(self, startOffset, endOffset)
end

local function combinedSpan(self, left, right)
	local a = left and left.sourceSpan
	local b = right and right.sourceSpan
	if a and b then
		return sourceSpan(self, math.min(a.startOffset, b.startOffset), math.max(a.endOffset, b.endOffset))
	elseif a then
		return a
	elseif b then
		return b
	end
end

local function markCombined(self, node, left, right)
	local span = combinedSpan(self, left, right)
	if span then node.sourceSpan = span end
	return node
end

local function markThrough(self, node, left, lastToken)
	local leftSpan = left and left.sourceSpan
	local startOffset = leftSpan and leftSpan.startOffset or (lastToken and lastToken.startPos) or 0
	local endOffset = lastToken and lastToken.endPos or startOffset
	node.sourceSpan = sourceSpan(self, startOffset, endOffset)
	return node
end

function Parser:new(settings)
	local luaVersion = (settings and (settings.luaVersion or settings.LuaVersion)) or LuaVersion.LuaU;
	local parser = {
		luaVersion = luaVersion,
		tokenizer = Tokenizer:new({
			luaVersion = luaVersion,
			AllowInternalIdentifiers = settings and settings.AllowInternalIdentifiers == true,
		}),
		tokens = {};
		length = 0;
		index = 0;
	};

	setmetatable(parser, self);
	self.__index = self;

	return parser;
end

-- Function to peek the n'th token
local function peek(self, n)
	n = n or 0;
	local i = self.index + n + 1;
	if i > self.length then
		return Tokenizer.EOF_TOKEN;
	end
	return self.tokens[i];
end

-- Function to get the next Token
local function get(self)
	local i = self.index + 1;
	if i > self.length then
		error(generateError(self, "Unexpected end of Input"));
	end
	self.index = self.index + 1;
	local tk = self.tokens[i];

	return tk;
end

local function is(self, kind, sourceOrN, n)
	local token = peek(self, n);

	local source = nil;
	if(type(sourceOrN) == "string") then
		source = sourceOrN;
	else
		n = sourceOrN;
	end
	n = n or 0;

	if(token.kind == kind) then
		if(source == nil or token.source == source) then
			return true;
		end
	end

	return false;
end

local function consume(self, kind, source)
	if(is(self, kind, source)) then
		self.index = self.index + 1;
		return true;
	end
	return false;
end

local function expect(self, kind, source)
	if(is(self, kind, source, 0)) then
		return get(self);
	end

	local token = peek(self);
	if self.disableLog then error() end
	if(source) then
		logger:error(generateError(self, string.format("unexpected token <%s> \"%s\", expected <%s> \"%s\"", token.kind, token.source, kind, source)));
	else
		logger:error(generateError(self, string.format("unexpected token <%s> \"%s\", expected <%s>", token.kind, token.source, kind)));
	end
end

-- Parse the given code to an Abstract Syntax Tree
function Parser:parse(code, source)
	local previousDisableLog = self.disableLog
	self.tokenizer:reset()
	self.tokens = {}
	self.index = 0
	self.length = 0
	if type(source) == "string" then
		self.sourceRecord = Source.new(source, code)
	elseif type(source) == "table" then
		self.sourceRecord = source
	else
		self.sourceRecord = Source.internal("snippet", code)
	end

	local ok, ast = pcall(function()
		self.tokenizer:append(code)
		self.tokens = self.tokenizer:scanAll()
		self.length = #self.tokens

		-- Begin transient name lookup at the chunk boundary
		local globalScope = Bindings:new()
		local parsedAst = Ast.TopNode(self:block(globalScope, false))
		-- File Must be Over when Top Node is Fully Parsed
		expect(self, TokenKind.Eof)

		-- The top node covers the complete input, including leading and trailing
		-- whitespace. All child nodes retain their narrower parser spans.
		Source.fill(parsedAst, sourceSpan(self, 0, #code))
		-- Keep direct Parser consumers on the same analyzed AST path as the pipeline.
		analyzeBindings(parsedAst)
		return parsedAst
	end)

	-- Always clear scanner/parser state so a failed parse does not poison reuse.
	self.tokenizer:reset()
	self.tokens = {}
	self.index = 0
	self.length = 0
	self.disableLog = previousDisableLog
	self.sourceRecord = nil
	if not ok then error(ast, 0) end
	return ast
end

-- Parse a Code Block
function Parser:block(parentScope, currentLoop, scope)
	scope = scope or Bindings:new(parentScope);
	local statements = {};

	repeat
		local statement, isTerminatingStatement = self:statement(scope, currentLoop);
		table.insert(statements, statement);
	until isTerminatingStatement or not statement

	-- Consume Eventual Semicolon after terminating return, break or continue
	consume(self, TokenKind.Symbol, ";");

	return Ast.Block(statements);
end

function Parser:statement(scope, currentLoop)
	-- Skip all semicolons before next real statement
	-- NOP statements are therefore ignored
	while(consume(self, TokenKind.Symbol, ";")) do

	end

	-- Break Statement - only valid inside of Loops
	if(consume(self, TokenKind.Keyword, "break")) then
		if(not currentLoop) then
			if self.disableLog then error() end;
			logger:error(generateError(self, "the break Statement is only valid inside of loops"));
		end
		-- Return true as Second value because break must be the last Statement in a block
		return Ast.BreakStatement(currentLoop), true;
	end

	-- Continue Statement - only valid inside of Loops - only valid in LuaU
	if(self.luaVersion == LuaVersion.LuaU and consume(self, TokenKind.Keyword, "continue")) then
		if(not currentLoop) then
			if self.disableLog then error() end;
			logger:error(generateError(self, "the continue Statement is only valid inside of loops"));
		end
		-- Return true as Second value because continue must be the last Statement in a block
		return Ast.ContinueStatement(currentLoop), true;
	end

	-- do ... end Statement
	if(consume(self, TokenKind.Keyword, "do")) then
		local body = self:block(scope, currentLoop);
		expect(self, TokenKind.Keyword, "end");
		return Ast.DoStatement(body);
	end

	-- While Statement
	if(consume(self, TokenKind.Keyword, "while")) then
		local condition = self:expression(scope);
		expect(self, TokenKind.Keyword, "do");
		local stat = Ast.WhileStatement(nil, condition);
		stat.body = self:block(scope, stat);
		expect(self, TokenKind.Keyword, "end");
		return stat;
	end

	-- Repeat Statement
	if(consume(self, TokenKind.Keyword, "repeat")) then
		local repeatScope = Bindings:new(scope);
		local stat = Ast.RepeatStatement(nil, nil);
		stat.body = self:block(nil, stat, repeatScope);
		expect(self, TokenKind.Keyword, "until");
		stat.condition = self:expression(repeatScope);
		return stat;
	end

	-- Return Statement
	if(consume(self, TokenKind.Keyword, "return")) then
		local args = {};
		if(not is(self, TokenKind.Keyword, "end") and not is(self, TokenKind.Keyword, "elseif") and not is(self, TokenKind.Keyword, "else") and not is(self, TokenKind.Symbol, ";") and not is(self, TokenKind.Eof)) then
			args = self:exprList(scope);
		end
		-- Return true as Second value because return must be the last Statement in a block
		return Ast.ReturnStatement(args), true;
	end

	-- If Statement
	if(consume(self, TokenKind.Keyword, "if")) then
		local condition = self:expression(scope);
		expect(self, TokenKind.Keyword, "then");
		local body = self:block(scope, currentLoop);

		local elseifs = {};
		-- Elseifs
		while(consume(self, TokenKind.Keyword, "elseif")) do
			local condition = self:expression(scope);
			expect(self, TokenKind.Keyword, "then");
			local body = self:block(scope, currentLoop);

			table.insert(elseifs, {
				condition = condition,
				body = body,
			});
		end

		local elsebody = nil;
		-- Else
		if(consume(self, TokenKind.Keyword, "else")) then
			elsebody = self:block(scope, currentLoop);
		end

		expect(self, TokenKind.Keyword, "end");

		return Ast.IfStatement(condition, body, elseifs, elsebody);
	end

	-- Function Declaration
	if(consume(self, TokenKind.Keyword, "function")) then
		-- TODO: Parse Function Declaration Name
		local obj = self:funcName(scope);
		local indices = obj.indices;

		local funcScope = Bindings:new(scope);

		expect(self, TokenKind.Symbol, "(");
		local args = self:functionArgList(funcScope);
		expect(self, TokenKind.Symbol, ")");

		if(obj.passSelf) then
			local symbol = funcScope:declare("self", obj.token);
			local selfArgument = Ast.VariableExpression(symbol)
			selfArgument.sourceSpan = tokenSpan(self, obj.token)
			table.insert(args, 1, selfArgument);
		end

		local body = self:block(nil, false, funcScope);
		expect(self, TokenKind.Keyword, "end");

		return Ast.FunctionDeclaration(obj.target, indices, args, body);
	end

	-- Local Function or Variable Declaration
	if(consume(self, TokenKind.Keyword, "local")) then
		-- Local Function Declaration
		if(consume(self, TokenKind.Keyword, "function")) then
			local ident = expect(self, TokenKind.Ident);
			local name = ident.value;

			local symbol = scope:declare(name, ident);
			local funcScope = Bindings:new(scope);

			expect(self, TokenKind.Symbol, "(");
			local args = self:functionArgList(funcScope);
			expect(self, TokenKind.Symbol, ")");

			local body = self:block(nil, false, funcScope);
			expect(self, TokenKind.Keyword, "end");

			return Ast.LocalFunctionDeclaration(symbol, args, body);
		end

		-- Local Variable Declaration
		local symbols = self:nameList(scope);
		local expressions = {};
		if(consume(self, TokenKind.Symbol, "=")) then
			expressions = self:exprList(scope);
		end

		-- Variables can only be reffered to in the next statement, so the symbol's are enabled after the expressions have been parsed
		self:enableNameList(scope, symbols);

		if(#expressions > #symbols) then
			logger:warn(generateWarning(peek(self, -1), string.format("assigning %d values to %d variable" .. ((#symbols > 1 and "s") or ""), #expressions, #symbols)));
		elseif(#symbols > #expressions and #expressions > 0 and not ASSIGNMENT_NO_WARN_LOOKUP[expressions[#expressions].kind]) then
			logger:warn(generateWarning(peek(self, -1), string.format("assigning %d value" .. ((#expressions > 1 and "s") or "") ..
				" to %d variables initializes extra variables with nil, add a nil value to silence", #expressions, #symbols)));
		end
		return Ast.LocalVariableDeclaration(symbols, expressions);
	end

	-- For Statement
	if(consume(self, TokenKind.Keyword, "for")) then
		local forToken = self.tokens[self.index]
		-- Normal for Statement
		if(is(self, TokenKind.Symbol, "=", 1)) then
			local forScope = Bindings:new(scope);

			local ident = expect(self, TokenKind.Ident);
			local symbol = forScope:create(ident.value, ident);

			expect(self, TokenKind.Symbol, "=");
			local initialValue = self:expression(scope);

			expect(self, TokenKind.Symbol, ",");
			local finalValue = self:expression(scope);
			local incrementBy = Ast.NumberExpression(1);
			incrementBy.sourceSpan = tokenSpan(self, forToken)
			if(consume(self, TokenKind.Symbol, ",")) then
				incrementBy = self:expression(scope);
			end

			local stat = Ast.ForStatement(symbol, initialValue, finalValue, incrementBy, nil);
			forScope:enable(symbol);
			expect(self, TokenKind.Keyword, "do");
			stat.body = self:block(nil, stat, forScope);
			expect(self, TokenKind.Keyword, "end");
			return stat;
		end

		-- For ... in ... statement
		local forScope = Bindings:new(scope);

		local symbols = self:nameList(forScope);
		expect(self, TokenKind.Keyword, "in");
		local expressions = self:exprList(scope);
		-- Enable Ids after Expression Parsing so that code like this works:
		--	local z = {10,20}
		--	for y,z in ipairs(z) do
		--		print(y, z);
		-- 	end
		self:enableNameList(forScope, symbols);
		expect(self, TokenKind.Keyword, "do");
		local stat = Ast.ForInStatement(symbols, expressions, nil);
		stat.body = self:block(nil, stat, forScope);
		expect(self, TokenKind.Keyword, "end");

		return stat;
	end

	local expr = self:primaryExpression(scope);
	-- Variable Assignment or Function Call
	if expr then
		-- Function Call Statement
		if(expr.kind == AstKind.FunctionCallExpression) then
			return Ast.FunctionCallStatement(expr.base, expr.args);
		end

		-- Function Call Statement passing self
		if(expr.kind == AstKind.PassSelfFunctionCallExpression) then
			return Ast.PassSelfFunctionCallStatement(expr.base, expr.passSelfFunctionName, expr.args);
		end

		-- Variable Assignment
		if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression or expr.kind == AstKind.GlobalVariableExpression) then
			if(expr.kind == AstKind.IndexExpression) then
				expr.kind = AstKind.AssignmentIndexing
			end
			if(expr.kind == AstKind.VariableExpression) then
				expr.kind = AstKind.AssignmentVariable
			elseif(expr.kind == AstKind.GlobalVariableExpression) then
				expr.kind = AstKind.AssignmentGlobalVariable
			end

			if(self.luaVersion == LuaVersion.LuaU) then
				-- LuaU Compound Assignment
				if(consume(self, TokenKind.Symbol, "+=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundAddStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "-=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundSubStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "*=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundMulStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "/=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundDivStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "%=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundModStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "^=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundPowStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "..=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundConcatStatement(expr, rhs);
				end
			end

			local lhs = {
				expr
			}

			while consume(self, TokenKind.Symbol, ",") do
				expr = self:primaryExpression(scope);

				if(not expr) then
					if self.disableLog then error() end;
					logger:error(generateError(self, string.format("expected a valid assignment statement lhs part but got nil")));
				end

				if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression or expr.kind == AstKind.GlobalVariableExpression) then
					if(expr.kind == AstKind.IndexExpression) then
						expr.kind = AstKind.AssignmentIndexing
					end
					if(expr.kind == AstKind.VariableExpression) then
						expr.kind = AstKind.AssignmentVariable
					elseif(expr.kind == AstKind.GlobalVariableExpression) then
						expr.kind = AstKind.AssignmentGlobalVariable
					end
					table.insert(lhs, expr);
				else
					if self.disableLog then error() end;
					logger:error(generateError(self, string.format("expected a valid assignment statement lhs part but got <%s>", expr.kind)));
				end
			end

			expect(self, TokenKind.Symbol, "=");

			local rhs = self:exprList(scope);

			return Ast.AssignmentStatement(lhs, rhs);
		end

		if self.disableLog then error() end;
		logger:error(generateError(self, "expressions are not valid statements!"));
	end

	return nil;
end

function Parser:primaryExpression(scope)
	local i = self.index;
	local s = self;
	local previousDisableLog = self.disableLog
	self.disableLog = true;
	local status, val = pcall(self.expressionFunctionCall, self, scope);
	self.disableLog = previousDisableLog;
	if(status) then
		return val;
	else
		self.index = i;
		return nil;
	end
end

-- List of expressions Seperated by a comma
function Parser:exprList(scope)
	local expressions = {
		self:expression(scope)
	};
	while(consume(self, TokenKind.Symbol, ",")) do
		table.insert(expressions, self:expression(scope));
	end
	return expressions;
end

-- list of local variable names
function Parser:nameList(scope)
	local symbols = {};

	local ident = expect(self, TokenKind.Ident);
	local symbol = scope:create(ident.value, ident);
	table.insert(symbols, symbol);

	while(consume(self, TokenKind.Symbol, ",")) do
		ident = expect(self, TokenKind.Ident);
		symbol = scope:create(ident.value, ident);
		table.insert(symbols, symbol);
	end

	return symbols;
end

function Parser:enableNameList(scope, list)
	for i, symbol in ipairs(list) do
		scope:enable(symbol);
	end
end


-- function name
function Parser:funcName(scope)
	local ident = expect(self, TokenKind.Ident);
	local baseName = ident.value;

		local target = scope:resolve(baseName);
		target.sourceSpan = tokenSpan(self, ident);

	local indices = {};
	local passSelf = false;
	while(consume(self, TokenKind.Symbol, ".")) do
		table.insert(indices, expect(self, TokenKind.Ident).value);
	end

	if(consume(self, TokenKind.Symbol, ":")) then
		table.insert(indices, expect(self, TokenKind.Ident).value);
		passSelf = true;
	end

	return {
		target = target,
		indices = indices,
		passSelf = passSelf,
		token = ident,
	};
end

-- Expression
function Parser:expression(scope)
	return self:expressionOr(scope);
end

function Parser:expressionOr(scope)
	local lhs = self:expressionAnd(scope);

	if(consume(self, TokenKind.Keyword, "or")) then
		local rhs = self:expressionOr(scope);
		return markCombined(self, Ast.OrExpression(lhs, rhs, true), lhs, rhs);
	end

	return lhs;
end

function Parser:expressionAnd(scope)
	local lhs = self:expressionComparision(scope);

	if(consume(self, TokenKind.Keyword, "and")) then
		local rhs = self:expressionAnd(scope);
		return markCombined(self, Ast.AndExpression(lhs, rhs, true), lhs, rhs);
	end

	return lhs;
end

function Parser:expressionComparision(scope)
	local curr = self:expressionStrCat(scope);
	repeat
		local found = false;
		if(consume(self, TokenKind.Symbol, "<")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.LessThanExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, ">")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.GreaterThanExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "<=")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.LessThanOrEqualsExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, ">=")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.GreaterThanOrEqualsExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "~=")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.NotEqualsExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "==")) then
			local rhs = self:expressionStrCat(scope);
			curr = markCombined(self, Ast.EqualsExpression(curr, rhs, true), curr, rhs);
			found = true;
		end
	until not found;

	return curr;
end

function Parser:expressionStrCat(scope)
	local lhs = self:expressionAddSub(scope);

	if(consume(self, TokenKind.Symbol, "..")) then
		local rhs = self:expressionStrCat(scope);
		return markCombined(self, Ast.StrCatExpression(lhs, rhs, true), lhs, rhs);
	end

	return lhs;
end

function Parser:expressionAddSub(scope)
	local curr = self:expressionMulDivMod(scope);

	repeat
		local found = false;
		if(consume(self, TokenKind.Symbol, "+")) then
			local rhs = self:expressionMulDivMod(scope);
			curr = markCombined(self, Ast.AddExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "-")) then
			local rhs = self:expressionMulDivMod(scope);
			curr = markCombined(self, Ast.SubExpression(curr, rhs, true), curr, rhs);
			found = true;
		end
	until not found;


	return curr;
end

function Parser:expressionMulDivMod(scope)
	local curr = self:expressionUnary(scope);

	repeat
		local found = false;
		if(consume(self, TokenKind.Symbol, "*")) then
			local rhs = self:expressionUnary(scope);
			curr = markCombined(self, Ast.MulExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "/")) then
			local rhs = self:expressionUnary(scope);
			curr = markCombined(self, Ast.DivExpression(curr, rhs, true), curr, rhs);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "%")) then
			local rhs = self:expressionUnary(scope);
			curr = markCombined(self, Ast.ModExpression(curr, rhs, true), curr, rhs);
			found = true;
		end
	until not found;

	return curr;
end

function Parser:expressionUnary(scope)
	if(consume(self, TokenKind.Keyword, "not")) then
		local rhs = self:expressionUnary(scope);
		return Ast.NotExpression(rhs, true);
	end

	if(consume(self, TokenKind.Symbol, "#")) then
		local rhs = self:expressionUnary(scope);
		return Ast.LenExpression(rhs, true);
	end

	if(consume(self, TokenKind.Symbol, "-")) then
		local rhs = self:expressionUnary(scope);
		return Ast.NegateExpression(rhs, true);
	end

	return self:expressionPow(scope);
end

function Parser:expressionPow(scope)
	local lhs = self:tableOrFunctionLiteral(scope);

	if(consume(self, TokenKind.Symbol, "^")) then
		-- Allow unary operators on the rhs (e.g. 2 ^ #x, 2 ^ -x) while preserving right-associativity. ~ SpinnySpiwal
		local rhs = self:expressionUnary(scope);
		return markCombined(self, Ast.PowExpression(lhs, rhs, true), lhs, rhs);
	end

	return lhs;
end

-- Table Literals and Function Literals cannot directly be called or indexed
function Parser:tableOrFunctionLiteral(scope)

	if(is(self, TokenKind.Symbol, "{")) then
		return self:tableConstructor(scope);
	end

	if(is(self, TokenKind.Keyword, "function")) then
		return self:expressionFunctionLiteral(scope);
	end

	return self:expressionFunctionCall(scope);
end

function Parser:expressionFunctionLiteral(parentScope)
	local scope = Bindings:new(parentScope);

	expect(self, TokenKind.Keyword, "function");

	expect(self, TokenKind.Symbol, "(");
	local args = self:functionArgList(scope);
	expect(self, TokenKind.Symbol, ")");

	local body = self:block(nil, false, scope);
	expect(self, TokenKind.Keyword, "end");

	return Ast.FunctionLiteralExpression(args, body);
end

function Parser:functionArgList(scope)
	local args = {};
	if(consume(self, TokenKind.Symbol, "...")) then
		local arg = Ast.VarargExpression();
		arg.sourceSpan = tokenSpan(self, self.tokens[self.index]);
		table.insert(args, arg);
		return args;
	end

	if(is(self, TokenKind.Ident)) then
		local ident = get(self);
		local name = ident.value;

		local symbol = scope:declare(name, ident);
		local arg = Ast.VariableExpression(symbol);
		arg.sourceSpan = tokenSpan(self, ident);
		table.insert(args, arg);

		while(consume(self, TokenKind.Symbol, ",")) do
			if(consume(self, TokenKind.Symbol, "...")) then
				local arg = Ast.VarargExpression();
				arg.sourceSpan = tokenSpan(self, self.tokens[self.index]);
				table.insert(args, arg);
				return args;
			end

			ident = get(self);
			name = ident.value;

			symbol = scope:declare(name, ident);
			local arg = Ast.VariableExpression(symbol);
			arg.sourceSpan = tokenSpan(self, ident);
			table.insert(args, arg);
		end
	end

	return args;
end

function Parser:expressionFunctionCall(scope, base)
	base = base or self:expressionIndex(scope);

	if(not (base and (CALLABLE_PREFIX_EXPRESSION_LOOKUP[base.kind] or base.isParenthesizedExpression))) then
		return base;
	end

	-- Normal Function Call
	local args = {};
	if(is(self, TokenKind.String)) then
		local stringToken = get(self)
		args = {
			Ast.StringExpression(stringToken.value),
		};
		args[1].sourceSpan = tokenSpan(self, stringToken)
	elseif(is(self, TokenKind.Symbol, "{")) then
		args = {
			self:tableConstructor(scope),
		};
	elseif(consume(self, TokenKind.Symbol, "(")) then
		if(not is(self, TokenKind.Symbol, ")")) then
			args = self:exprList(scope);
		end
		expect(self, TokenKind.Symbol, ")");
	else
		return base;
	end

	local node = markThrough(self, Ast.FunctionCallExpression(base, args), base, self.tokens[self.index]);

	-- the result of a function call can be indexed
	if(is(self, TokenKind.Symbol, ".") or is(self, TokenKind.Symbol, "[") or is(self, TokenKind.Symbol, ":")) then
		return self:expressionIndex(scope, node);
	end

	-- The result of a function call can be a function that is again called
	if(is(self, TokenKind.Symbol, "(") or is(self, TokenKind.Symbol, "{") or is(self, TokenKind.String)) then
		return self:expressionFunctionCall(scope, node);
	end

	return node;
end

function Parser:expressionIndex(scope, base)
	base = base or self:expressionLiteral(scope);

	-- Parse Indexing Expressions
	while(consume(self, TokenKind.Symbol, "[")) do
		local expr = self:expression(scope);
		expect(self, TokenKind.Symbol, "]");
		base = markThrough(self, Ast.IndexExpression(base, expr), base, self.tokens[self.index]);
	end

	-- Parse Indexing Expressions
	while consume(self, TokenKind.Symbol, ".") do
		local ident = expect(self, TokenKind.Ident);
		local key = Ast.StringExpression(ident.value)
		key.sourceSpan = tokenSpan(self, ident)
		base = markThrough(self, Ast.IndexExpression(base, key), base, ident)

		while(consume(self, TokenKind.Symbol, "[")) do
			local expr = self:expression(scope);
			expect(self, TokenKind.Symbol, "]");
			base = markThrough(self, Ast.IndexExpression(base, expr), base, self.tokens[self.index]);
		end
	end

	-- Function Passing self
	if(consume(self, TokenKind.Symbol, ":")) then
		local passSelfFunctionName = expect(self, TokenKind.Ident).value;
		local args = {};
		if(is(self, TokenKind.String)) then
			local stringToken = get(self)
			args = {
				Ast.StringExpression(stringToken.value),
			};
			args[1].sourceSpan = tokenSpan(self, stringToken)
		elseif(is(self, TokenKind.Symbol, "{")) then
			args = {
				self:tableConstructor(scope),
			};
		else
			expect(self, TokenKind.Symbol, "(");
			if(not is(self, TokenKind.Symbol, ")")) then
				args = self:exprList(scope);
			end
			expect(self, TokenKind.Symbol, ")");
		end

		local node = markThrough(self, Ast.PassSelfFunctionCallExpression(base, passSelfFunctionName, args), base, self.tokens[self.index]);

		-- the result of a function call can be indexed
		if(is(self, TokenKind.Symbol, ".") or is(self, TokenKind.Symbol, "[") or is(self, TokenKind.Symbol, ":")) then
			return self:expressionIndex(scope, node);
		end

		-- The result of a function call can be a function that is again called
		if(is(self, TokenKind.Symbol, "(") or is(self, TokenKind.Symbol, "{") or is(self, TokenKind.String)) then
			return self:expressionFunctionCall(scope, node);
		end

		return node
	end

	-- The result of a function call can be a function that is again called
	if(is(self, TokenKind.Symbol, "(") or is(self, TokenKind.Symbol, "{") or is(self, TokenKind.String)) then
		return self:expressionFunctionCall(scope, base);
	end

	return base;
end

function Parser:expressionLiteral(scope)
	-- () expression
	if(is(self, TokenKind.Symbol, "(")) then
		local open = get(self)
		local expr = self:expression(scope);
		local close = expect(self, TokenKind.Symbol, ")");
		if expr then
			expr.isParenthesizedExpression = true;
			expr.sourceSpan = sourceSpan(self, open.startPos, close.endPos)
		end
		return expr;
	end

	-- String Literal
	if(is(self, TokenKind.String)) then
		return Ast.StringExpression(get(self).value);
	end

	-- Number Literal
	if(is(self, TokenKind.Number)) then
		return Ast.NumberExpression(get(self).value);
	end

	-- True Literal
	if(consume(self, TokenKind.Keyword, "true")) then
		return Ast.BooleanExpression(true);
	end

	-- False Literal
	if(consume(self, TokenKind.Keyword, "false")) then
		return Ast.BooleanExpression(false);
	end

	-- Nil Literal
	if(consume(self, TokenKind.Keyword, "nil")) then
		return Ast.NilExpression();
	end

	-- Vararg Literal
	if(consume(self, TokenKind.Symbol, "...")) then
		return Ast.VarargExpression();
	end

	-- Variable
	if(is(self, TokenKind.Ident)) then
		local ident = get(self);
		local name = ident.value;

		return scope:resolve(name);
	end

	-- IfElse
	if(LuaVersion.LuaU) then
		if(consume(self, TokenKind.Keyword, "if")) then
			local condition = self:expression(scope);
			expect(self, TokenKind.Keyword, "then");
			local true_value = self:expression(scope);

			local elseifs = {}
			while(consume(self, TokenKind.Keyword, "elseif")) do
				local elseif_condition = self:expression(scope);
				expect(self, TokenKind.Keyword, "then");
				local elseif_value = self:expression(scope);

				table.insert(elseifs, {
					condition = elseif_condition,
					value = elseif_value
				});
			end

			expect(self, TokenKind.Keyword, "else");
			local false_value = self:expression(scope);

			return Ast.IfElseExpression(condition, true_value, elseifs, false_value);
		end
	end

	if(self.disableLog) then error() end
	logger:error(generateError(self, "Unexpected Token \"" .. peek(self).source .. "\". Expected a Expression!"))
end

function Parser:tableConstructor(scope)
	-- TODO: Parse Table Literals
	local entries = {};

	expect(self, TokenKind.Symbol, "{");

	while (not consume(self, TokenKind.Symbol, "}")) do
		local entryStart = self.index + 1
		if(consume(self, TokenKind.Symbol, "[")) then
			local key = self:expression(scope);
			expect(self, TokenKind.Symbol, "]");
			expect(self, TokenKind.Symbol, "=");
			local value = self:expression(scope);
			local entry = Ast.KeyedTableEntry(key, value)
			entry.sourceSpan = parserRangeSpan(self, entryStart, self.index)
			table.insert(entries, entry);
		elseif(is(self, TokenKind.Ident, 0) and is(self, TokenKind.Symbol, "=", 1)) then
			local ident = get(self)
			local key = Ast.StringExpression(ident.value)
			key.sourceSpan = tokenSpan(self, ident)
			expect(self, TokenKind.Symbol, "=");
			local value = self:expression(scope);
			local entry = Ast.KeyedTableEntry(key, value)
			entry.sourceSpan = parserRangeSpan(self, entryStart, self.index)
			table.insert(entries, entry);
		else
			local value = self:expression(scope);
			local entry = Ast.TableEntry(value)
			entry.sourceSpan = parserRangeSpan(self, entryStart, self.index)
			table.insert(entries, entry);
		end


		if (not consume(self, TokenKind.Symbol, ";") and not consume(self, TokenKind.Symbol, ",") and not is(self, TokenKind.Symbol, "}")) then
			if self.disableLog then error() end
			logger:error(generateError(self, "expected a \";\" or a \",\""));
		end
	end

	return Ast.TableConstructorExpression(entries);
end

-- Fill each parser method's result with the token range consumed by that
-- production. Recursive productions have already attached narrower spans to
-- their children, and explicit operator/call/index spans below preserve the
-- exact range for nodes assembled from multiple productions.
local spanProductions = {
	"block", "statement", "primaryExpression", "exprList",
	"expression", "expressionOr", "expressionAnd", "expressionComparision",
	"expressionStrCat", "expressionAddSub", "expressionMulDivMod",
	"expressionUnary", "expressionPow", "tableOrFunctionLiteral",
	"expressionFunctionLiteral", "expressionFunctionCall", "expressionIndex",
	"expressionLiteral", "tableConstructor",
}

local function wrapSpanProduction(name)
	local production = Parser[name]
	Parser[name] = function(self, ...)
		local firstIndex = self.index + 1
		if name == "statement" then
			while self.tokens[firstIndex]
				and self.tokens[firstIndex].kind == TokenKind.Symbol
				and self.tokens[firstIndex].source == ";" do
				firstIndex = firstIndex + 1
			end
		end
		local result = {production(self, ...)}
		local node = result[1]
		if type(node) == "table" and AstKind[node.kind] and not node.sourceSpan then
			node.sourceSpan = parserRangeSpan(self, firstIndex, self.index)
		end
		return unpack(result)
	end
end

for _, name in ipairs(spanProductions) do
	wrapSpanProduction(name)
end

return Parser

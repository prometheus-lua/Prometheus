-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- parser.lua
-- Overview:
-- This Script provides a class for parsing of lua code.
-- This Parser is Capable of parsing LuaU and Lua5.1
--
-- Settings Object:
-- luaVersion : The LuaVersion of the Script - Currently Supported : Lua51 and LuaU
-- AllowInternalIdentifiers : Skip reserved-prefix warnings for generated code (default false)
--

local Tokenizer = require("prometheus.tokenizer");
local Enums = require("prometheus.enums");
local util = require("prometheus.util");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger");
local lowerExports = require("prometheus.luau_exports");
local lowerIteration = require("prometheus.luau_iteration");

local AstKind = Ast.AstKind;

local LuaVersion = Enums.LuaVersion;
local lookupify = util.lookupify;

local TokenKind = Tokenizer.TokenKind;

local Parser = {};

local ASSIGNMENT_NO_WARN_LOOKUP = lookupify{
	AstKind.NilExpression,
	AstKind.FunctionCallExpression,
	AstKind.PassSelfFunctionCallExpression,
	AstKind.VarargExpression
};

local CALLABLE_PREFIX_EXPRESSION_LOOKUP = lookupify{
	AstKind.VariableExpression,
	AstKind.IndexExpression,
	AstKind.FunctionCallExpression,
	AstKind.PassSelfFunctionCallExpression
};

local function generateError(self, message)
	local token;
	if(self.index > self.length) then
		token = self.tokens[self.length];
	elseif(self.index < 1) then
		token = self.tokens[1];
		if not token then return "Parsing Error at Position 0:0, " .. message end
	else
		token = self.tokens[self.index];
	end

	return "Parsing Error at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
end

local function generateWarning(token, message)
	return "Warning at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
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
		lowerLuauIteration = settings and settings.LowerLuauIteration == true;
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
	local source;
	if type(sourceOrN) == "number" then
		n = sourceOrN;
	else
		source = sourceOrN;
	end
	local tk = peek(self, n);
	return tk.kind == kind and (source == nil or tk.source == source);
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

require("prometheus.luau_types")(Parser, TokenKind, is, consume, expect, peek, get);
require("prometheus.luau_attributes")(Parser, TokenKind, is, consume, expect, peek, get);

local function markConst(scope, id)
	scope.constBindings = scope.constBindings or {};
	scope.constBindings[id] = true;
end

local function assertMutable(self, scope, id)
	scope.assignedBindings = scope.assignedBindings or {};
	scope.assignedBindings[id] = true;
	if scope.constBindings and scope.constBindings[id] then
		if self.disableLog then error() end
		logger:error(generateError(self, string.format("Cannot reassign constant '%s'", scope:getVariableName(id))));
	end
end

-- Match Luau's reachable-branch check for locals skipped by repeat/continue.
local function repeatContinue(block, loop)
	for _, node in ipairs(block.statements) do
		if node.kind == AstKind.ContinueStatement then
			return node.loop == loop and node.sourceToken or nil;
		elseif node.kind == AstKind.ReturnStatement or node.kind == AstKind.BreakStatement then
			return nil;
		elseif node.kind == AstKind.DoStatement then
			local found = repeatContinue(node.body, loop);
			if found then return found end
		elseif node.kind == AstKind.IfStatement then
			local branches = {{condition = node.condition, body = node.body}};
			for _, branch in ipairs(node.elseifs) do branches[#branches + 1] = branch end
			local remaining = true;
			for _, branch in ipairs(branches) do
				if remaining and (not branch.condition.isConstant or branch.condition.value) then
					local found = repeatContinue(branch.body, loop);
					if found then return found end
					if branch.condition.isConstant then remaining = false end
				end
			end
			if remaining and node.elsebody then
				local found = repeatContinue(node.elsebody, loop);
				if found then return found end
			end
		end
	end
end

-- Parse the given code to an Abstract Syntax Tree
function Parser:parse(code)
	-- A failed parse must not leave input behind for the next invocation.
	self.tokenizer:reset();
	self.tokens, self.index, self.length = {}, 0, 0;
	self.disableLog = false;
	self.noSimplify = false;
	self.varargAllowed = true;
	self.functionDepth = 0;
	self.lexicalScope = nil;
	self.typeFunctionRoot = nil;
	self.moduleScope = nil;
	self.exportBindings, self.exportNames = {}, {};
	self.hasModuleReturn = false;
	self.tokenizer:append(code);
	self.tokens = self.tokenizer:scanAll();

	self.length = #self.tokens;

	-- Create Global Variable Scope
	local globalScope = Scope:newGlobal();

	local ast = Ast.TopNode(self:block(globalScope, false), globalScope);
	ast.luaVersion = self.luaVersion;
	ast.directives = self.luaVersion == LuaVersion.LuaU and self.tokenizer.directives or nil;
	-- File Must be Over when Top Node is Fully Parsed
	expect(self, TokenKind.Eof);
	if #self.exportBindings > 0 then lowerExports(ast, self.exportBindings) end
	if self.luaVersion == LuaVersion.LuaU and self.lowerLuauIteration then lowerIteration(ast, Parser) end

	logger:debug("Cleaning up Parser for next Use ...")
	-- Clean Up
	self.tokenizer:reset();
	self.tokens = {};
	self.index = 0;
	self.length = 0;

	logger:debug("Cleanup Done")

	return ast;
end

-- Parse a Code Block
function Parser:block(parentScope, currentLoop, scope)
	scope = scope or Scope:new(parentScope);
	if not self.moduleScope then self.moduleScope = scope end
	local savedScope = self.lexicalScope;
	self.lexicalScope = scope;
	local statements = {};

	while true do
		-- Erased type declarations still count as statements for semicolon syntax.
		local declaration = self:parseLuauDeclaration();
		local statement, isTerminatingStatement;
		if not declaration then statement, isTerminatingStatement = self:statement(scope, currentLoop) end
		if not declaration and not statement then break end
		if statement then table.insert(statements, statement) end
		consume(self, TokenKind.Symbol, ";");
		if isTerminatingStatement then break end
	end

	self.lexicalScope = savedScope;
	return Ast.Block(statements, scope);
end

function Parser:statement(scope, currentLoop)
	local attributes = self:parseLuauAttributes(scope);
	if attributes then
		local node, terminating = self:statement(scope, currentLoop);
		if not node or (node.kind ~= AstKind.FunctionDeclaration and node.kind ~= AstKind.LocalFunctionDeclaration) then
			logger:error(generateError(self, "Function attributes require a function declaration"));
		end
		if node.attributes then logger:error(generateError(self, "Duplicate function attribute list")) end
		node.attributes = attributes;
		return node, terminating;
	end
	if self.luaVersion == LuaVersion.LuaU and is(self, TokenKind.Ident, "export")
		and (is(self, TokenKind.Keyword, "local", 1) or is(self, TokenKind.Keyword, "function", 1) or is(self, TokenKind.Ident, "const", 1)) then
		get(self);
		if scope ~= self.moduleScope or self.functionDepth ~= 0 then logger:error(generateError(self, "Value exports require a top-level statement")) end
		if self.hasModuleReturn then logger:error(generateError(self, "Value exports conflict with a top-level return")) end
		local node;
		if consume(self, TokenKind.Keyword, "function") then
			local ident = expect(self, TokenKind.Ident);
			local id = scope:addVariable(ident.value, ident);
			markConst(scope, id);
			local funcScope = Scope:new(scope);
			self:parseLuauGenerics();
			expect(self, TokenKind.Symbol, "(");
			local args = self:functionArgList(funcScope);
			expect(self, TokenKind.Symbol, ")");
			self:parseLuauReturnAnnotation();
			local body = self:functionBody(funcScope, args);
			expect(self, TokenKind.Keyword, "end");
			node = Ast.LocalFunctionDeclaration(scope, id, args, body);
		else
			if is(self, TokenKind.Keyword, "function", 1) or is(self, TokenKind.Symbol, "@", 1) then
				logger:error(generateError(self, "Use 'export function' for an exported function"));
			end
			node = self:statement(scope, currentLoop);
			if not node or node.kind ~= AstKind.LocalVariableDeclaration then logger:error(generateError(self, "Expected an exported binding")) end
		end
		node.isExported = true;
		for _, id in ipairs(node.ids or {node.id}) do
			local name = scope:getVariableName(id);
			if self.exportNames[name] then logger:error(generateError(self, "Duplicate exported identifier '" .. name .. "'")) end
			self.exportNames[name] = true;
			self.exportBindings[#self.exportBindings + 1] = {scope = scope, id = id, name = name};
		end
		return node;
	end
	-- Preserve the legacy Lua 5.1 empty-statement behavior. Luau permits only
	-- one optional semicolon after an actual statement, consumed by block().
	if self.luaVersion == LuaVersion.Lua51 then
		while consume(self, TokenKind.Symbol, ";") do end
	end

	-- Break Statement - only valid inside of Loops
	if(consume(self, TokenKind.Keyword, "break")) then
		if(not currentLoop) then
			if self.disableLog then error() end;
			logger:error(generateError(self, "the break Statement is only valid inside of loops"));
		end
		-- Return true as Second value because break must be the last Statement in a block
		return Ast.BreakStatement(currentLoop, scope), true;
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
		local stat = Ast.WhileStatement(nil, condition, scope);
		stat.body = self:block(scope, stat);
		expect(self, TokenKind.Keyword, "end");
		return stat;
	end

	-- Repeat Statement
	if(consume(self, TokenKind.Keyword, "repeat")) then
		local repeatScope = Scope:new(scope);
		local stat = Ast.RepeatStatement(nil, nil, scope);
		stat.body = self:block(nil, stat, repeatScope);
		expect(self, TokenKind.Keyword, "until");
		stat.condition = self:expression(repeatScope);
		stat.continueToken = repeatContinue(stat.body, stat);
		if self.luaVersion == LuaVersion.LuaU and stat.continueToken then
			local visitast = require("prometheus.visitast");
			visitast(Ast.TopNode(Ast.Block({Ast.ReturnStatement{stat.condition}}, repeatScope), scope), function(node, data)
				if node.kind == AstKind.VariableExpression and node.scope == repeatScope then
					local declaration = repeatScope.declarationTokens and repeatScope.declarationTokens[node.id];
					local capturedConstant = data.functionData.depth > 0 and repeatScope.constantInitializers
						and repeatScope.constantInitializers[node.id] and not (repeatScope.assignedBindings and repeatScope.assignedBindings[node.id]);
					if declaration and declaration.startPos > stat.continueToken.startPos and not capturedConstant then
						logger:error(generateError(self, "Local '" .. repeatScope:getVariableName(node.id)
							.. "' in the repeat condition is skipped by continue"));
					end
				end
			end);
		end
		return stat;
	end

	-- Return Statement
	if(consume(self, TokenKind.Keyword, "return")) then
		if self.luaVersion == LuaVersion.LuaU and self.functionDepth == 0 then
			self.hasModuleReturn = true;
			if #self.exportBindings > 0 then logger:error(generateError(self, "Value exports conflict with a top-level return")) end
		end
		local args = {};
		if(not is(self, TokenKind.Keyword, "end") and not is(self, TokenKind.Keyword, "elseif") and not is(self, TokenKind.Keyword, "else") and not is(self, TokenKind.Keyword, "until") and not is(self, TokenKind.Symbol, ";") and not is(self, TokenKind.Eof)) then
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
		local baseScope = obj.scope;
		local baseId = obj.id;
		local indices = obj.indices;
		if #indices == 0 then assertMutable(self, baseScope, baseId) end

		local funcScope = Scope:new(scope);

		self:parseLuauGenerics();
		expect(self, TokenKind.Symbol, "(");
		local args = self:functionArgList(funcScope);
		expect(self, TokenKind.Symbol, ")");
		self:parseLuauReturnAnnotation();

		if(obj.passSelf) then
			local id = funcScope:addVariable("self", obj.token);
			table.insert(args, 1, Ast.VariableExpression(funcScope, id));
		end

		local body = self:functionBody(funcScope, args);
		expect(self, TokenKind.Keyword, "end");

		return Ast.FunctionDeclaration(baseScope, baseId, indices, args, body);
	end

	-- 'const' is contextual and remains a valid identifier outside declarations.
	local isConst = self.luaVersion == LuaVersion.LuaU and is(self, TokenKind.Ident, "const")
		and (is(self, TokenKind.Ident, nil, 1) or is(self, TokenKind.Keyword, "function", 1) or is(self, TokenKind.Symbol, "@", 1));
	if consume(self, TokenKind.Keyword, "local") or (isConst and consume(self, TokenKind.Ident, "const")) then
		-- Local Function Declaration
		if(consume(self, TokenKind.Keyword, "function")) then
			local ident = expect(self, TokenKind.Ident);
			local name = ident.value;

			local id = scope:addVariable(name, ident);
			if isConst then markConst(scope, id) end
			local funcScope = Scope:new(scope);

			self:parseLuauGenerics();
			expect(self, TokenKind.Symbol, "(");
			local args = self:functionArgList(funcScope);
			expect(self, TokenKind.Symbol, ")");
			self:parseLuauReturnAnnotation();

			local body = self:functionBody(funcScope, args);
			expect(self, TokenKind.Keyword, "end");

			return Ast.LocalFunctionDeclaration(scope, id, args, body);
		end

		-- Local Variable Declaration
		local ids = self:nameList(scope);
		if isConst then
			for _, id in ipairs(ids) do markConst(scope, id) end
		end
		local expressions = {};
		if(consume(self, TokenKind.Symbol, "=")) then
			expressions = self:exprList(scope);
		elseif isConst then
			if self.disableLog then error() end
			logger:error(generateError(self, "A const declaration requires an initializer"));
		end

		if isConst and #expressions < #ids then
			local last = expressions[#expressions];
			local expands = last and not last.isParenthesizedExpression
				and (last.kind == AstKind.FunctionCallExpression or last.kind == AstKind.PassSelfFunctionCallExpression
					or last.kind == AstKind.VarargExpression);
			if not expands then
				if self.disableLog then error() end
				logger:error(generateError(self, "A const declaration requires an initializer for each binding"));
			end
		end

		-- Variables can only be reffered to in the next statement, so the id's are enabled after the expressions have been parsed
		scope.constantInitializers = scope.constantInitializers or {};
		for i, id in ipairs(ids) do
			if expressions[i] and expressions[i].isConstant then scope.constantInitializers[id] = true end
		end
		self:enableNameList(scope, ids);

		if(#expressions > #ids) then
			logger:warn(generateWarning(peek(self, -1), string.format("assigning %d values to %d variable" .. ((#ids > 1 and "s") or ""), #expressions, #ids)));
		elseif(#ids > #expressions and #expressions > 0 and not ASSIGNMENT_NO_WARN_LOOKUP[expressions[#expressions].kind]) then
			logger:warn(generateWarning(peek(self, -1), string.format("assigning %d value" .. ((#expressions > 1 and "s") or "") ..
				" to %d variables initializes extra variables with nil, add a nil value to silence", #expressions, #ids)));
		end
		return Ast.LocalVariableDeclaration(scope, ids, expressions);
	end

	-- For Statement
	if(consume(self, TokenKind.Keyword, "for")) then
		-- Normal for Statement
		local savedIndex = self.index;
		expect(self, TokenKind.Ident);
		self:parseLuauTypeAnnotation();
		local isNumericFor = is(self, TokenKind.Symbol, "=");
		self.index = savedIndex;
		if(isNumericFor) then
			local forScope = Scope:new(scope);

			local ident = expect(self, TokenKind.Ident);
			local varId = forScope:addDisabledVariable(ident.value, ident);
			self:parseLuauTypeAnnotation();

			expect(self, TokenKind.Symbol, "=");
			local initialValue = self:expression(scope);

			expect(self, TokenKind.Symbol, ",");
			local finalValue = self:expression(scope);
			local incrementBy = Ast.NumberExpression(1);
			if(consume(self, TokenKind.Symbol, ",")) then
				incrementBy = self:expression(scope);
			end

			local stat = Ast.ForStatement(forScope, varId, initialValue, finalValue, incrementBy, nil, scope);
			forScope:enableVariable(varId);
			expect(self, TokenKind.Keyword, "do");
			stat.body = self:block(nil, stat, forScope);
			expect(self, TokenKind.Keyword, "end");
			return stat;
		end

		-- For ... in ... statement
		local forScope = Scope:new(scope);

		local ids = self:nameList(forScope);
		expect(self, TokenKind.Keyword, "in");
		local expressions = self:exprList(scope);
		-- Enable Ids after Expression Parsing so that code like this works:
		--	local z = {10,20}
		--	for y,z in ipairs(z) do
		--		print(y, z);
		-- 	end
		self:enableNameList(forScope, ids);
		expect(self, TokenKind.Keyword, "do");
		local stat = Ast.ForInStatement(forScope, ids, expressions, nil, scope);
		stat.body = self:block(nil, stat, forScope);
		expect(self, TokenKind.Keyword, "end");

		return stat;
	end

	local expr = self:primaryExpression(scope);
	-- Variable Assignment or Function Call
	if expr then
		if expr.isInterpolatedStringExpression then
			if self.disableLog then error() end
			logger:error(generateError(self, "An interpolated string is not a valid statement"));
		end
		-- Function Call Statement
		if(expr.kind == AstKind.FunctionCallExpression) then
			return Ast.FunctionCallStatement(expr.base, expr.args);
		end

		-- Function Call Statement passing self
		if(expr.kind == AstKind.PassSelfFunctionCallExpression) then
			return Ast.PassSelfFunctionCallStatement(expr.base, expr.passSelfFunctionName, expr.args);
		end

		-- Variable Assignment
		if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression) then
			-- A call or assignment using this name takes precedence over continue.
			local nextToken = peek(self);
			local assignmentFollows = nextToken.kind == TokenKind.Symbol
				and (nextToken.source == "=" or nextToken.source == "," or nextToken.source:match("^[+%-%*/%%%^%.]+=$"));
			if self.luaVersion == LuaVersion.LuaU and expr.kind == AstKind.VariableExpression
				and not expr.isParenthesizedExpression and expr.scope:getVariableName(expr.id) == "continue"
				and not assignmentFollows then
				if not currentLoop then
					if self.disableLog then error() end
					logger:error(generateError(self, "the continue Statement is only valid inside of loops"));
				end
				local node = Ast.ContinueStatement(currentLoop, scope);
				node.sourceToken = peek(self, -1);
				return node, true;
			end
			if(expr.kind == AstKind.IndexExpression) then
				if expr.isParenthesizedExpression then logger:error(generateError(self, "Assigned expression must be a variable or field")) end
				expr.kind = AstKind.AssignmentIndexing
			end
			if(expr.kind == AstKind.VariableExpression) then
				if expr.isParenthesizedExpression then logger:error(generateError(self, "Assigned expression must be a variable or field")) end
				expr.kind = AstKind.AssignmentVariable
				assertMutable(self, expr.scope, expr.id);
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

				if(consume(self, TokenKind.Symbol, "//=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundFloorDivStatement(expr, rhs);
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

				if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression) then
					if expr.isParenthesizedExpression then logger:error(generateError(self, "Assigned expression must be a variable or field")) end
					if(expr.kind == AstKind.IndexExpression) then
						expr.kind = AstKind.AssignmentIndexing
					end
					if(expr.kind == AstKind.VariableExpression) then
						expr.kind = AstKind.AssignmentVariable
						assertMutable(self, expr.scope, expr.id);
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
	local tk = peek(self);
	if tk.kind == TokenKind.Eof or (tk.kind == TokenKind.Keyword
		and (tk.source == "end" or tk.source == "else" or tk.source == "elseif" or tk.source == "until")) then
		return nil;
	end
	-- Invalid calls must keep their diagnostics, including vararg and type errors.
	return self:expressionFunctionCall(scope);
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
	local ids = {};

	local ident = expect(self, TokenKind.Ident);
	local id = scope:addDisabledVariable(ident.value, ident);
	self:parseLuauTypeAnnotation();
	table.insert(ids, id);

	while(consume(self, TokenKind.Symbol, ",")) do
		ident = expect(self, TokenKind.Ident);
		id = scope:addDisabledVariable(ident.value, ident);
		self:parseLuauTypeAnnotation();
		table.insert(ids, id);
	end

	return ids;
end

function Parser:enableNameList(scope, list)
	for i, id in ipairs(list) do
		scope:enableVariable(id);
	end
end


-- function name
function Parser:funcName(scope)
	local ident = expect(self, TokenKind.Ident);
	local baseName = ident.value;

	local baseScope, baseId = scope:resolve(baseName);

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
		scope = baseScope,
		id = baseId,
		indices = indices,
		passSelf = passSelf,
		token = ident,
	};
end

-- Expression
function Parser:expression(scope)
	local savedScope = self.lexicalScope;
	self.lexicalScope = scope;
	local result = self:expressionOr(scope);
	self.lexicalScope = savedScope;
	return result;
end

function Parser:expressionOr(scope)
	local lhs = self:expressionAnd(scope);

	if(consume(self, TokenKind.Keyword, "or")) then
		local rhs = self:expressionOr(scope);
		return Ast.OrExpression(lhs, rhs, not self.noSimplify);
	end

	return lhs;
end

function Parser:expressionAnd(scope)
	local lhs = self:expressionComparision(scope);

	if(consume(self, TokenKind.Keyword, "and")) then
		local rhs = self:expressionAnd(scope);
		return Ast.AndExpression(lhs, rhs, not self.noSimplify);
	end

	return lhs;
end

function Parser:expressionComparision(scope)
	local curr = self:expressionStrCat(scope);
	repeat
		local found = false;
		if(consume(self, TokenKind.Symbol, "<")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.LessThanExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, ">")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.GreaterThanExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "<=")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.LessThanOrEqualsExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, ">=")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.GreaterThanOrEqualsExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "~=")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.NotEqualsExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "==")) then
			local rhs = self:expressionStrCat(scope);
			curr = Ast.EqualsExpression(curr, rhs, not self.noSimplify);
			found = true;
		end
	until not found;

	return curr;
end

function Parser:expressionStrCat(scope)
	local lhs = self:expressionAddSub(scope);

	if(consume(self, TokenKind.Symbol, "..")) then
		local rhs = self:expressionStrCat(scope);
		return Ast.StrCatExpression(lhs, rhs, not self.noSimplify);
	end

	return lhs;
end

function Parser:expressionAddSub(scope)
	local curr = self:expressionMulDivMod(scope);

	repeat
		local found = false;
		if(consume(self, TokenKind.Symbol, "+")) then
			local rhs = self:expressionMulDivMod(scope);
			curr = Ast.AddExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "-")) then
			local rhs = self:expressionMulDivMod(scope);
			curr = Ast.SubExpression(curr, rhs, not self.noSimplify);
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
			curr = Ast.MulExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "/")) then
			local rhs = self:expressionUnary(scope);
			curr = Ast.DivExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "//")) then
			local rhs = self:expressionUnary(scope);
			curr = Ast.FloorDivExpression(curr, rhs, not self.noSimplify);
			found = true;
		end

		if(consume(self, TokenKind.Symbol, "%")) then
			local rhs = self:expressionUnary(scope);
			curr = Ast.ModExpression(curr, rhs, not self.noSimplify);
			found = true;
		end
	until not found;

	return curr;
end

function Parser:expressionUnary(scope)
	if(consume(self, TokenKind.Keyword, "not")) then
		local rhs = self:expressionUnary(scope);
		return Ast.NotExpression(rhs, not self.noSimplify);
	end

	if(consume(self, TokenKind.Symbol, "#")) then
		local rhs = self:expressionUnary(scope);
		return Ast.LenExpression(rhs, not self.noSimplify);
	end

	if(consume(self, TokenKind.Symbol, "-")) then
		local rhs = self:expressionUnary(scope);
		return Ast.NegateExpression(rhs, not self.noSimplify);
	end

	return self:expressionPow(scope);
end

function Parser:expressionPow(scope)
	local lhs = self:tableOrFunctionLiteral(scope);

	if self:parseLuauCast() then
		if lhs.kind == AstKind.FunctionCallExpression or lhs.kind == AstKind.PassSelfFunctionCallExpression or lhs.kind == AstKind.VarargExpression then
			lhs.isParenthesizedExpression = true;
		end
	end

	if(consume(self, TokenKind.Symbol, "^")) then
		-- Allow unary operators on the rhs (e.g. 2 ^ #x, 2 ^ -x) while preserving right-associativity. ~ SpinnySpiwal
		local rhs = self:expressionUnary(scope);
		return Ast.PowExpression(lhs, rhs, not self.noSimplify);
	end

	return lhs;
end

-- Table Literals and Function Literals cannot directly be called or indexed
function Parser:tableOrFunctionLiteral(scope)
	local attributes = self:parseLuauAttributes(scope);
	if attributes then return self:expressionFunctionLiteral(scope, attributes) end

	if(is(self, TokenKind.Symbol, "{")) then
		return self:tableConstructor(scope);
	end

	if(is(self, TokenKind.Keyword, "function")) then
		return self:expressionFunctionLiteral(scope);
	end

	return self:expressionFunctionCall(scope);
end

function Parser:expressionFunctionLiteral(parentScope, attributes)
	local scope = Scope:new(parentScope);

	expect(self, TokenKind.Keyword, "function");

	self:parseLuauGenerics();
	expect(self, TokenKind.Symbol, "(");
	local args = self:functionArgList(scope);
	expect(self, TokenKind.Symbol, ")");
	self:parseLuauReturnAnnotation();

	local body = self:functionBody(scope, args);
	expect(self, TokenKind.Keyword, "end");

	local node = Ast.FunctionLiteralExpression(args, body);
	node.attributes = attributes;
	return node;
end

-- An inner function never inherits its enclosing function's vararg parameter.
-- Signature annotations are parsed before entering the new function context.
function Parser:functionBody(scope, args)
	local savedVararg = self.varargAllowed;
	self.varargAllowed = #args > 0 and args[#args].kind == AstKind.VarargExpression;
	self.functionDepth = self.functionDepth + 1;
	local body = self:block(nil, false, scope);
	self.functionDepth = self.functionDepth - 1;
	self.varargAllowed = savedVararg;
	return body;
end

function Parser:functionArgList(scope)
	local args = {};
	if(consume(self, TokenKind.Symbol, "...")) then
		self:parseLuauVarargAnnotation();
		table.insert(args, Ast.VarargExpression());
		return args;
	end

	if(is(self, TokenKind.Ident)) then
		local ident = get(self);
		local name = ident.value;
		self:parseLuauTypeAnnotation();

		local id = scope:addVariable(name, ident);
		table.insert(args, Ast.VariableExpression(scope, id));

		while(consume(self, TokenKind.Symbol, ",")) do
			if(consume(self, TokenKind.Symbol, "...")) then
				self:parseLuauVarargAnnotation();
				table.insert(args, Ast.VarargExpression());
				return args;
			end

			ident = expect(self, TokenKind.Ident);
			name = ident.value;
			self:parseLuauTypeAnnotation();

			id = scope:addVariable(name, ident);
			table.insert(args, Ast.VariableExpression(scope, id));
		end
	end

	return args;
end

local function checkCallLine(self)
	if self.luaVersion == LuaVersion.LuaU and is(self, TokenKind.Symbol, "(")
		and peek(self, -1).line ~= peek(self).line then
		local message = generateError(self, "Ambiguous function call; use ';' to separate statements");
		if self.disableLog then error(message, 0) end
		logger:error(message);
	end
end

function Parser:expressionFunctionCall(scope, base)
	base = base or self:expressionIndex(scope);

	if(not (base and (CALLABLE_PREFIX_EXPRESSION_LOOKUP[base.kind] or base.isParenthesizedExpression))) then
		return base;
	end

	local instantiated = false;
	while self:parseLuauInstantiation() do
		instantiated = true;
		if base.kind == AstKind.FunctionCallExpression or base.kind == AstKind.PassSelfFunctionCallExpression then
			base.isParenthesizedExpression = true;
		end
	end
	if instantiated and (is(self, TokenKind.Symbol, ".") or is(self, TokenKind.Symbol, "[") or is(self, TokenKind.Symbol, ":")) then
		return self:expressionFunctionCall(scope, self:expressionIndex(scope, base));
	end
	checkCallLine(self);
	-- Normal Function Call
	local args = {};
	if(is(self, TokenKind.String)) then
		args = {
			Ast.StringExpression(get(self).value),
		};
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

	local node = Ast.FunctionCallExpression(base, args);

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
		base = Ast.IndexExpression(base, expr);
	end

	-- Parse Indexing Expressions
	while consume(self, TokenKind.Symbol, ".") do
		local ident = expect(self, TokenKind.Ident);
		base = Ast.IndexExpression(base, Ast.StringExpression(ident.value));

		while(consume(self, TokenKind.Symbol, "[")) do
			local expr = self:expression(scope);
			expect(self, TokenKind.Symbol, "]");
			base = Ast.IndexExpression(base, expr);
		end
	end

	-- Function Passing self
	if(consume(self, TokenKind.Symbol, ":")) then
		local passSelfFunctionName = expect(self, TokenKind.Ident).value;
		self:parseLuauInstantiation();
		local args = {};
		checkCallLine(self);
		if(is(self, TokenKind.String)) then
			args = {
				Ast.StringExpression(get(self).value),
			};
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

		local node = Ast.PassSelfFunctionCallExpression(base, passSelfFunctionName, args);

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

function Parser:interpolatedString(scope, parts)
	local format, expressions = {}, {};
	for _, part in ipairs(parts) do
		if part.literal then
			format[#format + 1] = part.literal:gsub("%%", "%%%%");
		else
			local savedTokens, savedIndex, savedLength = self.tokens, self.index, self.length;
			self.tokens, self.index, self.length = part.tokens, 0, #part.tokens;
			local ok, expression = pcall(function()
				local result = self:expression(scope);
				expect(self, TokenKind.Eof);
				return result;
			end);
			self.tokens, self.index, self.length = savedTokens, savedIndex, savedLength;
			if not ok then error(expression, 0) end
			if expression.kind == AstKind.FunctionCallExpression or expression.kind == AstKind.PassSelfFunctionCallExpression
				or expression.kind == AstKind.VarargExpression then
				expression.isParenthesizedExpression = true;
			end
			expressions[#expressions + 1] = expression;
			format[#format + 1] = "%*";
		end
	end
	local template = table.concat(format);
	if #expressions == 0 then
		return Ast.StringExpression(template:gsub("%%%%", "%%"));
	end
	-- Luau's %* formatting has interpolation's conversion and evaluation order.
	-- Looking up the string method avoids shadowing of the global string library.
	local result = Ast.PassSelfFunctionCallExpression(Ast.StringExpression(template), "format", expressions);
	result.isParenthesizedExpression = true;
	result.isInterpolatedStringExpression = true;
	return result;
end

function Parser:expressionLiteral(scope)
	-- () expression
	if(consume(self, TokenKind.Symbol, "(")) then
		local expr = self:expression(scope);
		expect(self, TokenKind.Symbol, ")");
		if expr then
			expr.isParenthesizedExpression = true;
		end
		return expr;
	end

	-- Luau interpolated string
	if(is(self, TokenKind.InterpolatedString)) then
		return self:interpolatedString(scope, get(self).value);
	end

	-- String Literal
	if(is(self, TokenKind.String)) then
		return Ast.StringExpression(get(self).value);
	end

	-- Number Literal
	if is(self, TokenKind.Integer) then return Ast.IntegerExpression(get(self).value) end
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
		if not self.varargAllowed then
			local message = generateError(self, "Cannot use '...' outside a vararg function");
			if self.disableLog then error(message, 0) end
			logger:error(message);
		end
		return Ast.VarargExpression();
	end

	-- Variable
	if(is(self, TokenKind.Ident)) then
		local ident = get(self);
		local name = ident.value;

		local scope, id = scope:resolve(name);
		if self.typeFunctionRoot and not scope.isGlobal then
			local current = scope;
			while current and current ~= self.typeFunctionRoot do current = current.parentScope end
			if not current then logger:error(generateError(self, "Type function cannot reference outer local '" .. name .. "'")) end
		end
		return Ast.VariableExpression(scope, id);
	end

	-- IfElse
	if(self.luaVersion == LuaVersion.LuaU) then
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
		if(consume(self, TokenKind.Symbol, "[")) then
			local key = self:expression(scope);
			expect(self, TokenKind.Symbol, "]");
			expect(self, TokenKind.Symbol, "=");
			local value = self:expression(scope);
			table.insert(entries, Ast.KeyedTableEntry(key, value));
		elseif(is(self, TokenKind.Ident, 0) and is(self, TokenKind.Symbol, "=", 1)) then
			local key = Ast.StringExpression(get(self).value);
			expect(self, TokenKind.Symbol, "=");
			local value = self:expression(scope);
			local entry = Ast.KeyedTableEntry(key, value);
			entry.isRecord = true;
			table.insert(entries, entry);
		else
			local value = self:expression(scope);
			table.insert(entries, Ast.TableEntry(value));
		end


		if (not consume(self, TokenKind.Symbol, ";") and not consume(self, TokenKind.Symbol, ",") and not is(self, TokenKind.Symbol, "}")) then
			if self.disableLog then error() end
			logger:error(generateError(self, "expected a \";\" or a \",\""));
		end
	end

	return Ast.TableConstructorExpression(entries);
end

return Parser

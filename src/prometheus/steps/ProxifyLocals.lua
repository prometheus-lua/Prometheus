-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- ProxifyLocals.lua
--
-- This Step wraps local values in proxy objects.

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local RandomLiterals = require("prometheus.randomLiterals")

local AstKind = Ast.AstKind
local ProxifyLocals = Step:extend()
ProxifyLocals.Description = "This Step wraps all locals into Proxy Objects"
ProxifyLocals.Name = "Proxify Locals"
ProxifyLocals.SettingsDescriptor = {
	LiteralType = {
		name = "LiteralType", description = "The type of the randomly generated literals",
		type = "enum", values = {"dictionary", "number", "string", "any"}, default = "string",
	},
}

local function shallowcopy(orig)
	local copy = {}
	for key, value in pairs(orig) do copy[key] = value end
	return copy
end

local function callNameGenerator(generatorFunction, ...)
	if type(generatorFunction) == "table" then generatorFunction = generatorFunction.generateName end
	return generatorFunction(...)
end

local MetatableExpressions = {
	{constructor = Ast.AddExpression, key = "__add"},
	{constructor = Ast.SubExpression, key = "__sub"},
	{constructor = Ast.IndexExpression, key = "__index"},
	{constructor = Ast.MulExpression, key = "__mul"},
	{constructor = Ast.DivExpression, key = "__div"},
	{constructor = Ast.PowExpression, key = "__pow"},
	{constructor = Ast.StrCatExpression, key = "__concat"},
}

function ProxifyLocals:init(_) end

local function generateLocalMetatableInfo(pipeline)
	local usedOps, info = {}, {}
	for _, name in ipairs({"setValue", "getValue", "index"}) do
		local op
		repeat op = MetatableExpressions[math.random(#MetatableExpressions)] until not usedOps[op]
		usedOps[op] = true
		info[name] = op
	end
	info.valueName = callNameGenerator(pipeline.namegenerator, math.random(1, 4096))
	return info
end

local function localSymbol(name)
	return Ast.LocalSymbol(name)
end

function ProxifyLocals:CreateAssignmentExpression(info, expr)
	local metatableVals = {}
	local setSelf, setArg = localSymbol(), localSymbol()
	local setFunction = Ast.FunctionLiteralExpression({setSelf, setArg}, Ast.Block({
		Ast.AssignmentStatement({
			Ast.AssignmentIndexing(Ast.VariableExpression(setSelf), Ast.StringExpression(info.valueName)),
		}, {Ast.VariableExpression(setArg)}),
	}))
	table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.setValue.key), setFunction))

	local getSelf, getArg = localSymbol(), localSymbol()
	local getValue
	if info.getValue.key == "__index" or info.setValue.key == "__index" then
		getValue = Ast.FunctionCallExpression(Ast.GlobalVariableExpression("rawget"), {
			Ast.VariableExpression(getSelf), Ast.StringExpression(info.valueName),
		})
	else
		getValue = Ast.IndexExpression(Ast.VariableExpression(getSelf), Ast.StringExpression(info.valueName))
	end
	local getFunction = Ast.FunctionLiteralExpression({getSelf, getArg}, Ast.Block({
		Ast.ReturnStatement({getValue}),
	}))
	table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.getValue.key), getFunction))

	return Ast.FunctionCallExpression(Ast.VariableExpression(self.setMetatableSymbol), {
		Ast.TableConstructorExpression({Ast.KeyedTableEntry(Ast.StringExpression(info.valueName), expr)}),
		Ast.TableConstructorExpression(metatableVals),
	})
end

function ProxifyLocals:apply(ast, pipeline)
	local localMetatableInfos = {}
	-- Rewrite exemptions belong to this invocation, including when the same
	-- step instance is applied repeatedly to an already transformed tree.
	local skipped, ignored = {}, {}
	local function isGlobal(node)
		return node.kind == AstKind.GlobalVariableExpression or node.kind == AstKind.AssignmentGlobalVariable
	end
	local function getLocalMetatableInfo(symbol)
		if not symbol or localMetatableInfos[symbol] == false then return nil end
		if localMetatableInfos[symbol] then return localMetatableInfos[symbol] end
		local info = generateLocalMetatableInfo(pipeline)
		localMetatableInfos[symbol] = info
		return info
	end
	local function disableMetatableInfo(symbol)
		if symbol then localMetatableInfos[symbol] = false end
	end

	self.setMetatableSymbol = localSymbol()
	self.emptyFunctionSymbol = localSymbol()
	-- Generated implementation bindings are never proxified themselves.
	localMetatableInfos[self.setMetatableSymbol] = false
	localMetatableInfos[self.emptyFunctionSymbol] = false
	self.emptyFunctionUsed = false
	local emptyFunctionDeclaration = Ast.LocalVariableDeclaration({self.emptyFunctionSymbol}, {
		Ast.FunctionLiteralExpression({}, Ast.Block({})),
	})
	skipped[emptyFunctionDeclaration] = true
	table.insert(ast.body.statements, 1, emptyFunctionDeclaration)

	visitast(ast, function(node)
		-- Declare first, then assign. The early declaration makes recursive
		-- references inside the function literal point at the same binding.
		if node.kind == AstKind.Block then
			local i = 1
			while i <= #node.statements do
				local statement = node.statements[i]
				if statement.kind == AstKind.LocalFunctionDeclaration then
					local info = getLocalMetatableInfo(statement.symbol)
					if info then
						local declaration = Ast.LocalVariableDeclaration({statement.symbol}, {})
						skipped[declaration] = true
						local literal = Ast.FunctionLiteralExpression(statement.args, statement.body)
						local target = Ast.AssignmentVariable(statement.symbol)
						ignored[target] = true
						local assignment = Ast.AssignmentStatement({target}, {
							self:CreateAssignmentExpression(info, literal),
						})
						skipped[assignment] = true
						node.statements[i] = declaration
						table.insert(node.statements, i + 1, assignment)
						i = i + 1
					end
				end
				i = i + 1
			end
		end

		if node.kind == AstKind.ForStatement then disableMetatableInfo(node.symbol) end
		if node.kind == AstKind.ForInStatement then
			for _, symbol in ipairs(node.symbols) do disableMetatableInfo(symbol) end
		end
		if node.kind == AstKind.FunctionDeclaration or node.kind == AstKind.LocalFunctionDeclaration
			or node.kind == AstKind.FunctionLiteralExpression then
			for _, arg in ipairs(node.args) do
				if arg.kind == AstKind.VariableExpression then disableMetatableInfo(arg.symbol)
				elseif arg.kind == "LocalSymbol" then disableMetatableInfo(arg) end
			end
		end

		if node.kind == AstKind.AssignmentStatement and not skipped[node]
			and #node.lhs == 1 and node.lhs[1].kind == AstKind.AssignmentVariable then
			local variable = node.lhs[1]
			local info = not isGlobal(variable) and getLocalMetatableInfo(variable.symbol)
			if info then
				local args = shallowcopy(node.rhs)
				local reference = Ast.VariableExpression(variable.symbol)
				ignored[reference] = true
				args[1] = info.setValue.constructor(reference, args[1])
				self.emptyFunctionUsed = true
				return Ast.FunctionCallStatement(Ast.VariableExpression(self.emptyFunctionSymbol), args)
			end
		end
	end, function(node)
		if node.kind == AstKind.LocalVariableDeclaration and not skipped[node] then
			for i, symbol in ipairs(node.symbols) do
				local info = getLocalMetatableInfo(symbol)
				if info then
					node.expressions[i] = self:CreateAssignmentExpression(info, node.expressions[i] or Ast.NilExpression())
				end
			end
		end
		if node.kind == AstKind.VariableExpression and not ignored[node] and not isGlobal(node) then
			local info = getLocalMetatableInfo(node.symbol)
			if info then
				local literal
				if self.LiteralType == "dictionary" then literal = RandomLiterals.Dictionary()
				elseif self.LiteralType == "number" then literal = RandomLiterals.Number()
				elseif self.LiteralType == "string" then literal = RandomLiterals.String(pipeline)
				else literal = RandomLiterals.Any(pipeline) end
				return info.getValue.constructor(node, literal)
			end
		end
		if node.kind == AstKind.AssignmentVariable and not ignored[node] and not isGlobal(node) then
			local info = getLocalMetatableInfo(node.symbol)
			if info then
				ignored[node] = true
				return Ast.AssignmentIndexing(node, Ast.StringExpression(info.valueName))
			end
		end
		if node.kind == AstKind.FunctionDeclaration and node.symbol then
			local info = getLocalMetatableInfo(node.symbol)
			if info then table.insert(node.indices, 1, info.valueName) end
		end
	end)

	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration({self.setMetatableSymbol}, {
		Ast.GlobalVariableExpression("setmetatable"),
	}))
end

return ProxifyLocals

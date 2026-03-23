-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
--
-- This Script provides an Obfuscation Step, that converts Number Literals to expressions
unpack = unpack or table.unpack

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local NumbersToExpressions = Step:extend()
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions"
NumbersToExpressions.Name = "Numbers To Expressions"

NumbersToExpressions.SettingsDescriptor = {
	Threshold = {
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	InternalThreshold = {
		type = "number",
		default = 0.2,
		min = 0,
		max = 0.8,
	},
}

--[[
	This function removes trailing zeros from a floating point number
]]
local function filterNumber(number)
	local formatted = string.format("%.50f", number)
	formatted = formatted:gsub("%.?0+$", "")
	if formatted:sub(-1) == "." then
		formatted = formatted:sub(1, -2)
	end
	return formatted
end

local function generateModuloExpression(n)
	local rhs = n + math.random(1, 100)
	local multiplier = math.random(1, 10)
	local lhs = n + (multiplier * rhs)
	return lhs, rhs
end

function NumbersToExpressions:init(settings)
	self.ExpressionGenerators = {
		function(val, depth) -- Addition
			local val2 = math.random(-2 ^ 20, 2 ^ 20)
			local diff = val - val2
			if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
				return false
			end
			return Ast.AddExpression(
				self:CreateNumberExpression(val2, depth),
				self:CreateNumberExpression(diff, depth),
				false
			)
		end,
		function(val, depth) -- Subtraction
			local val2 = math.random(-2 ^ 20, 2 ^ 20)
			local diff = val + val2
			if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
				return false
			end
			return Ast.SubExpression(
				self:CreateNumberExpression(diff, depth),
				self:CreateNumberExpression(val2, depth),
				false
			)
		end,
		function(val, depth) -- Multiplication
			local val2 = math.random(-2 ^ 20, 2 ^ 20)
			local product = val * val2
			if tonumber(tostring(product)) ~= val then
				return false
			end
			return Ast.MulExpression(
				self:CreateNumberExpression(val2, depth),
				self:CreateNumberExpression(product, depth),
				false
			)
		end,
		function(val, depth) -- Advanced Modulo
			if val <= 0 then
				return false
			end
			local lhs, rhs = generateModuloExpression(val)
			return Ast.ModExpression(
				Ast.NumberExpression(filterNumber(lhs)),
				Ast.NumberExpression(filterNumber(rhs)),
				false
			)
		end,
	}
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
	if depth > 0 and math.random() >= self.InternalThreshold or depth > 15 then
		return Ast.NumberExpression(val)
	end

	local generators = util.shuffle({ unpack(self.ExpressionGenerators) })
	for i, generator in ipairs(generators) do
		local node = generator(val, depth + 1)
		if node then
			return node
		end
	end

	return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
	visitast(ast, nil, function(node, data)
		if node.kind == AstKind.NumberExpression then
			if math.random() <= self.Threshold then
				return self:CreateNumberExpression(node.value, 0)
			end
		end
	end)
end

return NumbersToExpressions

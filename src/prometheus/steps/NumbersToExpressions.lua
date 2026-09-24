-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- NumbersToExpressions.lua
--
-- This Script provides an Obfuscation Step, that converts Number Literals to expressions.
-- This step can now also convert numbers to different representations!
-- Supported representations: hex, binary, scientific, normal. Please note that binary is only supported in Lua 5.2 and above.

unpack = unpack or table.unpack

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")
local logger = require("logger")
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

	NumberRepresentationMutation = {
		type = "boolean",
		default = false,
		aliases = { "NumberRepresentationMutaton" },
	},

	AllowedNumberRepresentations = {
		type = "table",
		default = {"hex", "scientific", "normal"},
		values = {"hex", "binary", "scientific", "normal"},
	},
}

local MAX_SAFE_INT = 9007199254740991 -- 2^53 - 1

local function isSafeInteger(n)
	return type(n) == "number"
		and n == math.floor(n)
		and n >= -MAX_SAFE_INT
		and n <= MAX_SAFE_INT
end

local function generateModuloExpression(n)
	if not isSafeInteger(n) then
		return nil
	end

	local offset = math.random(1, 2 ^ 24)
	local rhs

	if n >= 0 then
		rhs = n + offset
	else
		rhs = n - offset
	end

	if rhs == 0 or not isSafeInteger(rhs) then
		return nil
	end

	local maxMultiplier = math.floor(
		(MAX_SAFE_INT - math.abs(n)) / math.abs(rhs)
	)

	maxMultiplier = math.min(maxMultiplier, 2 ^ 8)

	if maxMultiplier < 1 then
		return nil
	end

	local multiplier = math.random(1, maxMultiplier)
	local lhs = n + multiplier * rhs

	if not isSafeInteger(lhs) then
		return nil
	end

	if lhs % rhs ~= n then
		return nil
	end

	return lhs, rhs
end

local function contains(table, value)
	for _, v in ipairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

function NumbersToExpressions:init(_)
	self.ExpressionGenerators = {
		function(val, depth) -- Addition
			local val2 = math.random(-2 ^ 20, 2 ^ 20)
			local diff = val - val2
			if diff + val2 ~= val then
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
			if diff - val2 ~= val then
				return false
			end
			return Ast.SubExpression(
				self:CreateNumberExpression(diff, depth),
				self:CreateNumberExpression(val2, depth),
				false
			)
		end,

		function(val, depth) -- Modulo
			local lhs, rhs = generateModuloExpression(val)

			if not lhs then
				return false
			end

			return Ast.ModExpression(
				self:CreateNumberExpression(lhs, depth),
				self:CreateNumberExpression(rhs, depth),
				false
			)
		end,
	}
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
	if (depth > 0 and math.random() >= self.InternalThreshold) or depth > 15 then
		if not self.NumberRepresentationMutation or type(val) ~= "number" then
			return Ast.NumberExpression(val)
		end

		local format = self.AllowedNumberRepresentations[math.random(1, #self.AllowedNumberRepresentations)]

		if format == "hex" then
			-- Lua 5.1 %X only supports positive 32-bit unsigned integers up to 0xFFFFFFFF
			if val == math.floor(val) and val >= 0 and val <= 0xFFFFFFFF then
				local hexStr = string.format("0x%X", val)
				if tonumber(hexStr) == val then
					local result = ""
					for i = 1, #hexStr do
						local c = hexStr:sub(i, i)
						if math.random() > 0.5 then
							result = result .. c:upper()
						else
							result = result .. c:lower()
						end
					end
					return Ast.NumberExpression(val, result)
				end
			end
			return Ast.NumberExpression(val)
		end

		if format == "binary" then
			if val == math.floor(val) and val >= 0 then
				local binary = ""
				local n = val
				if n == 0 then
					binary = "0"
				else
					while n > 0 do
						binary = (n % 2) .. binary
						n = math.floor(n / 2)
					end
				end
				local binStr = "0b" .. binary
				return Ast.NumberExpression(val, binStr)
			end
			return Ast.NumberExpression(val)
		end

		if format == "scientific" then
			if val ~= 0 then
				local exp = math.floor(math.log10(math.abs(val)))
				local mantissa = val / (10 ^ exp)
				local sciStr = string.format("%.15ge%d", mantissa, exp)
				-- Ensure parsing it back produces the exact same numeric value!
				if tonumber(sciStr) == val then
					return Ast.NumberExpression(val, sciStr)
				end
			end
			return Ast.NumberExpression(val)
		end

		if format == "normal" then
			return Ast.NumberExpression(val)
		end
	end

	local generators = util.shuffle({ unpack(self.ExpressionGenerators) })
	for _, generator in ipairs(generators) do
		local node = generator(val, depth + 1)
		if node then
			return node
		end
	end
	return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
	if contains(self.AllowedNumberRepresentations, "binary") then
		logger:warn("Warning: Binary representation is only supported in Lua 5.2 and above!")
	end

	visitast(ast, nil, function(node, _)
		if node.kind == AstKind.NumberExpression then
			if math.random() <= self.Threshold then
				return self:CreateNumberExpression(node.value, 0)
			end
		end
	end)
end

return NumbersToExpressions

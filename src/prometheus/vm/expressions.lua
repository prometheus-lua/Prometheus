local Ast = require("prometheus.ast")
local Kind = Ast.AstKind
local compileTable = require("prometheus.vm.expressions_tables")

local binary = {
	[Kind.AddExpression] = "ADD", [Kind.SubExpression] = "SUB",
	[Kind.MulExpression] = "MUL", [Kind.DivExpression] = "DIV",
	[Kind.ModExpression] = "MOD", [Kind.PowExpression] = "POW",
	[Kind.StrCatExpression] = "CONCAT", [Kind.LessThanExpression] = "LT",
	[Kind.LessThanOrEqualsExpression] = "LE", [Kind.GreaterThanExpression] = "GT",
	[Kind.GreaterThanOrEqualsExpression] = "GE", [Kind.EqualsExpression] = "EQ",
	[Kind.NotEqualsExpression] = "NE",
}
local unary = {
	[Kind.NotExpression] = "NOT", [Kind.NegateExpression] = "NEG",
	[Kind.LenExpression] = "LEN",
}

local function install(Compiler)
	local function load(self, value)
		return self:load(value)
	end

	local function numberValue(value)
		if type(value) ~= "string" then return value end
		local prefix = value:sub(1, 2):lower()
		if prefix == "0b" then
			local result = 0
			for i = 3, #value do
				local digit = value:sub(i, i)
				assert(digit == "0" or digit == "1", "invalid binary number: " .. value)
				result = result * 2 + (digit == "1" and 1 or 0)
			end
			return result
		end
		local number = tonumber(value)
		assert(number ~= nil, "invalid numeric literal: " .. value)
		return number
	end

	local function packed(self, regs, tail)
		local result = self:alloc()
		self:emit("ARGS", result, regs, tail or 0)
		return result
	end

	local function expandable(node)
		if not node or node.isParenthesizedExpression then return false end
		return node.kind == Kind.FunctionCallExpression
			or node.kind == Kind.PassSelfFunctionCallExpression
			or node.kind == Kind.VarargExpression
	end

	local function packList(self, expressions, prefix)
		local regs = {}
		for i, reg in ipairs(prefix or {}) do regs[i] = reg end
		local tail = 0
		for i, node in ipairs(expressions) do
			if i == #expressions and expandable(node) then
				if node.kind == Kind.VarargExpression then
					tail = self:alloc()
					self:emit("VARARG", tail)
				else
					tail = self:call(node, -1)[1]
				end
			else
				regs[#regs + 1] = self:expression(node, 1)[1]
			end
		end
		local result = packed(self, regs, tail)
		for _, reg in ipairs(regs) do self:free(reg) end
		if tail ~= 0 then self:free(tail) end
		return result
	end

	local function scalar(self, node)
		local kind = node.kind
		if kind == Kind.NilExpression then
			local reg = self:alloc(); self:emit("NIL", reg); return reg
		elseif kind == Kind.NumberExpression then
			return load(self, numberValue(node.value))
		elseif kind == Kind.BooleanExpression or kind == Kind.StringExpression then
			return load(self, node.value)
		elseif kind == Kind.VariableExpression then
			return self:readVariable(node.scope, node.id)
		elseif kind == Kind.VarargExpression then
			local tuple = self:alloc(); self:emit("VARARG", tuple)
			local reg = self:alloc(); self:emit("TAKE", reg, tuple, 1)
			self:free(tuple); return reg
		elseif kind == Kind.IndexExpression then
			local base = self:expression(node.base, 1)[1]
			local key = self:expression(node.index, 1)[1]
			local result = self:alloc(); self:emit("GETTABLE", result, base, key)
			self:free(key); self:free(base); return result
		elseif binary[kind] then
			local left = self:expression(node.lhs, 1)[1]
			local right = self:expression(node.rhs, 1)[1]
			local result = self:alloc(); self:emit(binary[kind], result, left, right)
			self:free(right); self:free(left); return result
		elseif unary[kind] then
			local source = self:expression(node.rhs, 1)[1]
			local result = self:alloc(); self:emit(unary[kind], result, source)
			self:free(source); return result
		elseif kind == Kind.AndExpression or kind == Kind.OrExpression then
			local left = self:expression(node.lhs, 1)[1]
			local result = self:alloc(); self:emit("MOVE", result, left)
			local branch = self:emit(kind == Kind.AndExpression and "JFALSE" or "JTRUE", left, 0)
			self:free(left)
			local right = self:expression(node.rhs, 1)[1]
			self:emit("MOVE", result, right); self:free(right)
			local endJump = self:emit("JMP", 0)
			local skipped = self:position()
			self:emit("CLEAR", left)
			local finish = self:position()
			self:patch(branch, 2, skipped)
			self:patch(endJump, 1, finish)
			return result
		elseif kind == Kind.IfElseExpression then
			local result = self:alloc()
			local endJumps = {}
			local condition = self:expression(node.condition, 1)[1]
			local nextBranch = self:emit("JFALSE", condition, 0); self:free(condition)
			local value = self:expression(node.true_value, 1)[1]
			self:emit("MOVE", result, value); self:free(value)
			endJumps[#endJumps + 1] = self:emit("JMP", 0)
			local falseStart = self:position()
			self:patch(nextBranch, 2, falseStart)
			self:emit("CLEAR", condition)
			for _, clause in ipairs(node.elseifs or {}) do
				condition = self:expression(clause.condition, 1)[1]
				nextBranch = self:emit("JFALSE", condition, 0); self:free(condition)
				value = self:expression(clause.value, 1)[1]
				self:emit("MOVE", result, value); self:free(value)
				endJumps[#endJumps + 1] = self:emit("JMP", 0)
				falseStart = self:position()
				self:patch(nextBranch, 2, falseStart)
				self:emit("CLEAR", condition)
			end
			value = self:expression(node.false_value, 1)[1]
			self:emit("MOVE", result, value); self:free(value)
			local finish = self:position()
			for _, jump in ipairs(endJumps) do self:patch(jump, 1, finish) end
			return result
		elseif kind == Kind.FunctionLiteralExpression then
			return self:functionLiteral(node)
		elseif kind == Kind.TableConstructorExpression then
			return compileTable(self, node)
		elseif kind == Kind.FunctionCallExpression or kind == Kind.PassSelfFunctionCallExpression then
			return self:call(node, 1)[1]
		end
		error("unsupported expression kind: " .. tostring(kind))
	end

	function Compiler:expression(node, count)
		count = count == nil and 1 or count
		local forceScalarPack = count == -1 and node.isParenthesizedExpression
		if forceScalarPack then count = 1 end
		if count == 0 then
			if node.kind == Kind.FunctionCallExpression or node.kind == Kind.PassSelfFunctionCallExpression then
				self:call(node, 0)
			else
				self:free(scalar(self, node))
			end
			return {}
		end
		if node.kind == Kind.FunctionCallExpression or node.kind == Kind.PassSelfFunctionCallExpression then
			local results = self:call(node, count)
			if forceScalarPack then
				local tuple = packed(self, {results[1]}, 0)
				self:free(results[1])
				return {tuple}
			end
			return results
		end
		if node.kind == Kind.VarargExpression and count ~= 1 then
			local tuple = self:alloc(); self:emit("VARARG", tuple)
			if count == -1 then return {tuple} end
			local results = {}
			for i = 1, count do
				results[i] = self:alloc(); self:emit("TAKE", results[i], tuple, i)
			end
			self:free(tuple); return results
		end
		local value = scalar(self, node)
		if forceScalarPack then
			local tuple = packed(self, {value}, 0)
			self:free(value)
			return {tuple}
		end
		if count == -1 then
			local tuple = packed(self, {value}, 0)
			self:free(value)
			return {tuple}
		end
		local results = {value}
		while #results < count do
			local nilReg = self:alloc(); self:emit("NIL", nilReg)
			results[#results + 1] = nilReg
		end
		return results
	end

	function Compiler:list(expressions, count)
		expressions = expressions or {}
		if count == 0 then
			for _, node in ipairs(expressions) do self:expression(node, 0) end
			return {}
		end
		local tuple = packList(self, expressions)
		if count == nil then return {tuple} end
		local results = {}
		for i = 1, count do
			results[i] = self:alloc(); self:emit("TAKE", results[i], tuple, i)
		end
		self:free(tuple)
		return results
	end

	function Compiler:call(node, count, tail)
		local fn, prefix
		if node.kind == Kind.PassSelfFunctionCallExpression then
			local object = self:expression(node.base, 1)[1]
			local key = load(self, node.passSelfFunctionName)
			fn = self:alloc(); self:emit("GETTABLE", fn, object, key)
			self:free(key)
			prefix = {object}
		else
			fn = self:expression(node.base, 1)[1]
		end
		local args = packList(self, node.args, prefix)
		if tail then
			self:emit("TAILCALL", fn, args)
			self:free(args); self:free(fn)
			return {}
		end
		if count == 0 then
			self:emit("CALL", 0, fn, args, 0)
			self:free(args); self:free(fn); return {}
		elseif count == -1 then
			local result = self:alloc(); self:emit("CALL", result, fn, args, -1)
			self:free(args); self:free(fn); return {result}
		elseif count == 1 then
			local result = self:alloc(); self:emit("CALL", result, fn, args, 1)
			self:free(args); self:free(fn); return {result}
		else
			local tuple = self:alloc(); self:emit("CALL", tuple, fn, args, -1)
			self:free(args); self:free(fn)
			local results = {}
			for i = 1, count do
				results[i] = self:alloc(); self:emit("TAKE", results[i], tuple, i)
			end
			self:free(tuple); return results
		end
	end
end

return install

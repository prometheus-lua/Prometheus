local Ast = require("prometheus.ast")
local Kind = Ast.AstKind

local function expandable(node)
	return node and not node.isParenthesizedExpression and
		(node.kind == Kind.FunctionCallExpression or
		 node.kind == Kind.PassSelfFunctionCallExpression or
		 node.kind == Kind.VarargExpression)
end

local function packed(self, registers, tail)
	local snapshot = {}
	for i, register in ipairs(registers) do snapshot[i] = register end
	local tuple = self:alloc()
	self:emit("ARGS", tuple, snapshot, tail or 0)
	return tuple
end

local function flush(self, tableReg, registers, firstIndex)
	if #registers == 0 then return end
	local tuple = packed(self, registers, 0)
	self:emit("EXPAND", tableReg, firstIndex, tuple)
	self:free(tuple)
	for _, register in ipairs(registers) do self:free(register) end
	for i = #registers, 1, -1 do registers[i] = nil end
end

return function(self, node)
	local tableReg = self:alloc()
	self:emit("TABLE", tableReg)
	local arrayIndex, batchStart, batch = 1, 1, {}
	for index, entry in ipairs(node.entries) do
		if entry.kind == Kind.TableEntry then
			if index == #node.entries and expandable(entry.value) then
				local tail
				if entry.value.kind == Kind.VarargExpression then
					tail = self:alloc()
					self:emit("VARARG", tail)
				else
					tail = self:call(entry.value, -1)[1]
				end
				local tuple = packed(self, batch, tail)
				self:emit("EXPAND", tableReg, batchStart, tuple)
				self:free(tuple)
				for _, register in ipairs(batch) do self:free(register) end
				for i = #batch, 1, -1 do batch[i] = nil end
				self:free(tail)
			else
				local value = self:expression(entry.value, 1)[1]
				batch[#batch + 1] = value
				arrayIndex = arrayIndex + 1
				if #batch == 1 then batchStart = arrayIndex - 1 end
				if #batch == 50 then
					flush(self, tableReg, batch, batchStart)
					batchStart = arrayIndex
				end
			end
		else
			local key = self:expression(entry.key, 1)[1]
			local value = self:expression(entry.value, 1)[1]
			self:emit("SETTABLE", tableReg, key, value)
			self:free(value)
			self:free(key)
		end
	end
	flush(self, tableReg, batch, batchStart)
	return tableReg
end

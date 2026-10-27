local Ast = require("prometheus.ast")
local K = Ast.AstKind

local function emitList(self, expressions, count)
	return self:list(expressions or {}, count)
end

local function release(self, regs)
	for _, reg in ipairs(regs or {}) do self:free(reg) end
end

local function emitWriteIndex(self, base, key, value)
	self:emit("SETTABLE", base, key, value)
end

return function(Compiler)
	function Compiler:cleanup(scope)
		if not scope or scope.isGlobal then return end
		for id = 1, #scope.variables do
			if scope.variables[id] then self:emit("CLEAR", self:localRegister(scope, id)) end
		end
	end

	function Compiler:cleanupTo(scopeDepth)
		for i = #self.scopeStack, scopeDepth + 1, -1 do
			self:cleanup(self.scopeStack[i])
		end
	end

	function Compiler:block(block, doCleanup)
		local scope = block.scope
		table.insert(self.scopeStack, scope)
		for _, statement in ipairs(block.statements) do self:statement(statement) end
		if doCleanup ~= false then self:cleanup(scope) end
		self.scopeStack[#self.scopeStack] = nil
	end

	local function loopFor(self, node)
		for i = #self.loops, 1, -1 do
			if self.loops[i].node == node then return self.loops[i] end
		end
		error("loop statement is not active")
	end

	local function loopRecord(self, node, continueDepth)
		local record = {
			node = node,
			scopeDepth = #self.scopeStack,
			continueDepth = continueDepth or #self.scopeStack,
			breaks = {},
			continues = {},
		}
		table.insert(self.loops, record)
		return record
	end

	local function finishLoop(self, record, breakTarget, continueTarget)
		for _, jump in ipairs(record.breaks) do self:patch(jump, 1, breakTarget) end
		for _, jump in ipairs(record.continues) do self:patch(jump, 1, continueTarget) end
		self.loops[#self.loops] = nil
	end

	local function compileIf(self, node)
		local done = {}
		local branches = {{condition = node.condition, body = node.body}}
		for _, branch in ipairs(node.elseifs or {}) do branches[#branches + 1] = branch end
		for _, branch in ipairs(branches) do
			local condition = self:expression(branch.condition, 1)[1]
			local skip = self:emit("JFALSE", condition, 0)
			self:free(condition)
			self:block(branch.body, true)
			done[#done + 1] = self:emit("JMP", 0)
			self:patch(skip, 2, self:position())
		end
		if node.elsebody then self:block(node.elsebody, true) end
		local endPos = self:position()
		for _, jump in ipairs(done) do self:patch(jump, 1, endPos) end
	end

	local function compileWhile(self, node)
		local record = loopRecord(self, node)
		local check = self:position()
		local condition = self:expression(node.condition, 1)[1]
		local exit = self:emit("JFALSE", condition, 0)
		self:block(node.body, true)
		local continueTarget = self:position()
		self:emit("JMP", check)
		local clearPos = self:position()
		self:patch(exit, 2, clearPos)
		finishLoop(self, record, clearPos, continueTarget)
		self:free(condition)
	end

	local function compileRepeat(self, node)
		local record = loopRecord(self, node, #self.scopeStack + 1)
		record.bodyScope = node.body.scope
		local start = self:position()
		self:block(node.body, false)
		local conditionPos = self:position()
		local condition = self:expression(node.condition, 1)[1]
		local leave = self:emit("JTRUE", condition, 0)
		self:free(condition)
		self:cleanup(node.body.scope)
		self:emit("JMP", start)
		local cleanupExit = self:position()
		self:patch(leave, 2, cleanupExit)
		self:cleanup(node.body.scope)
		local endPos = self:position()
		finishLoop(self, record, endPos, conditionPos)
	end

	local function compileNumericFor(self, node)
		local control = emitList(self, {node.initialValue, node.finalValue, node.incrementBy}, 3)
		self:emit("FORPREP", control[1], control[2], control[3])
		local record = loopRecord(self, node)
		local check = self:position()
		local ok = self:alloc()
		self:emit("FORCHECK", ok, control[1], control[2], control[3])
		local exit = self:emit("JFALSE", ok, 0)
		self:initVariable(node.scope, node.id, control[1])
		self:block(node.body, true)
		local advance = self:position()
		local nextValue = self:alloc()
		self:emit("ADD", nextValue, control[1], control[3])
		self:emit("MOVE", control[1], nextValue)
		self:emit("CLEAR", nextValue)
		self:emit("JMP", check)
		local endPos = self:position()
		self:patch(exit, 2, endPos)
		finishLoop(self, record, endPos, advance)
		self:free(ok)
		self:free(nextValue)
		release(self, control)
	end

	local function compileGenericFor(self, node)
		local values = emitList(self, node.expressions, 3)
		local iterator, state, control = values[1], values[2], values[3]
		local record = loopRecord(self, node)
		local check = self:position()
		local results = self:alloc()
		self:emit("CALL2", results, iterator, {state, control}, -1)
		local first = self:alloc()
		self:emit("TAKE", first, results, 1)
		local nilreg, ended = self:alloc(), self:alloc()
		local iterationTemps = {results, first, nilreg, ended}
		self:emit("NIL", nilreg)
		self:emit("EQ", ended, first, nilreg)
		local exit = self:emit("JTRUE", ended, 0)
		self:emit("MOVE", control, first)
		for i, id in ipairs(node.ids or node.vars) do
			local value = self:alloc()
			self:emit("TAKE", value, results, i)
			self:initVariable(node.scope, id, value)
			iterationTemps[#iterationTemps + 1] = value
		end
		for _, reg in ipairs(iterationTemps) do self:emit("CLEAR", reg) end
		self:block(node.body, true)
		local continueTarget = self:position()
		self:emit("JMP", check)
		local endPos = self:position()
		self:patch(exit, 2, endPos)
		finishLoop(self, record, endPos, continueTarget)
		release(self, iterationTemps)
		release(self, values)
	end

	local function assignmentTarget(self, target)
		if target.kind == K.AssignmentVariable then return {scope = target.scope, id = target.id} end
		if target.kind == K.AssignmentIndexing then
			local base = self:expression(target.base, 1)[1]
			local key = self:expression(target.index, 1)[1]
			return {base = base, key = key}
		end
		error("invalid assignment target: " .. tostring(target.kind))
	end

	local function storeTarget(self, target, value)
		if target.scope then self:writeVariable(target.scope, target.id, value)
		else emitWriteIndex(self, target.base, target.key, value) end
	end

	local function compileAssignment(self, node)
		local targets = {}
		for i, target in ipairs(node.lhs) do targets[i] = assignmentTarget(self, target) end
		local values = emitList(self, node.rhs, #targets)
		-- Lua stores a parallel assignment from right to left after evaluating RHSs.
		for i = #targets, 1, -1 do storeTarget(self, targets[i], values[i]) end
		release(self, values)
		for _, target in ipairs(targets) do
			if target.base then self:free(target.base); self:free(target.key) end
		end
	end

	local compoundOp = {
		[K.CompoundAddStatement] = "ADD", [K.CompoundSubStatement] = "SUB",
		[K.CompoundMulStatement] = "MUL", [K.CompoundDivStatement] = "DIV",
		[K.CompoundModStatement] = "MOD", [K.CompoundPowStatement] = "POW",
		[K.CompoundConcatStatement] = "CONCAT",
	}

	local function compileCompound(self, node)
		local target = assignmentTarget(self, node.lhs)
		local old = self:alloc()
		if target.scope then
			local value = self:readVariable(target.scope, target.id)
			self:emit("MOVE", old, value)
			self:free(value)
		else
			self:emit("GETTABLE", old, target.base, target.key)
		end
		local rhs = self:expression(node.rhs, 1)[1]
		local result = self:alloc()
		self:emit(compoundOp[node.kind], result, old, rhs)
		storeTarget(self, target, result)
		release(self, {old, rhs, result})
		if target.base then self:free(target.base); self:free(target.key) end
	end

	local function compileLocal(self, node)
		local values = emitList(self, node.expressions, #node.ids)
		for i, id in ipairs(node.ids) do self:initVariable(node.scope, id, values[i]) end
		release(self, values)
	end

	local function compileFunctionDeclaration(self, node)
		local indexed = #node.indices > 0
		local base = indexed and self:readVariable(node.scope, node.id) or nil
		if indexed then
			for i = 1, #node.indices - 1 do
				local key, nextBase = self:load(node.indices[i]), self:alloc()
				self:emit("GETTABLE", nextBase, base, key)
				self:free(base); self:free(key)
				base = nextBase
			end
		end
		local fn = self:functionLiteral(node)
		if indexed then
			local key = self:load(node.indices[#node.indices])
			self:emit("SETTABLE", base, key, fn)
			self:free(key); self:free(base)
		else
			self:writeVariable(node.scope, node.id, fn)
		end
		self:free(fn)
	end

	function Compiler:statement(node)
		local kind = node.kind
		if kind == K.NopStatement then return
		elseif kind == K.DoStatement then self:block(node.body, true)
		elseif kind == K.IfStatement then compileIf(self, node)
		elseif kind == K.WhileStatement then compileWhile(self, node)
		elseif kind == K.RepeatStatement then compileRepeat(self, node)
		elseif kind == K.ForStatement then compileNumericFor(self, node)
		elseif kind == K.ForInStatement then compileGenericFor(self, node)
		elseif kind == K.LocalVariableDeclaration then compileLocal(self, node)
		elseif kind == K.AssignmentStatement then compileAssignment(self, node)
		elseif compoundOp[kind] then compileCompound(self, node)
		elseif kind == K.LocalFunctionDeclaration then
			local nilreg = self:load(nil)
			self:initVariable(node.scope, node.id, nilreg)
			self:free(nilreg)
			local fn = self:functionLiteral(node)
			self:writeVariable(node.scope, node.id, fn)
			self:free(fn)
		elseif kind == K.FunctionDeclaration then compileFunctionDeclaration(self, node)
		elseif kind == K.BreakStatement or kind == K.ContinueStatement then
			local record = loopFor(self, node.loop)
			local depth = kind == K.ContinueStatement and record.continueDepth or record.scopeDepth
			self:cleanupTo(depth)
			local jump = self:emit("JMP", 0)
			local list = kind == K.ContinueStatement and record.continues or record.breaks
			list[#list + 1] = jump
		elseif kind == K.ReturnStatement then
			if #node.args == 1 and not node.args[1].isParenthesizedExpression
				and (node.args[1].kind == K.FunctionCallExpression or node.args[1].kind == K.PassSelfFunctionCallExpression) then
				self:call(node.args[1], -1, true)
				return
			end
			if self:fixedReturn(node.args) then return end
			local values = emitList(self, node.args, nil)
			self:emit("RETURN", values[1])
			release(self, values)
		elseif kind == K.FunctionCallStatement or kind == K.PassSelfFunctionCallStatement then
			local call = {kind = kind == K.FunctionCallStatement and K.FunctionCallExpression or K.PassSelfFunctionCallExpression,
				base = node.base, args = node.args, passSelfFunctionName = node.passSelfFunctionName}
			self:call(call, 0, false)
		else error("unsupported statement: " .. tostring(kind)) end
	end
end

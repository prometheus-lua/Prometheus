-- Lower scoped AST nodes into function prototypes containing semantic instructions.
local analyze = require('prometheus.vm.analysis')
local opcodes = require('prometheus.vm.opcodes')
local optimize = require('prometheus.vm.optimize')
local Compiler = {}
Compiler.__index = Compiler

function Compiler:new(analysis, node, parent)
    local compiler = setmetatable({
        analysis = analysis, owner = node.body.scope, parent = parent,
        proto = {code = {}, constants = {}, children = {}, captures = {},
            params = {}, vararg = node.kind == 'TopNode', maxRegister = 0},
        locals = {}, upvalues = {}, constantIds = {}, registers = {}, freeRegisters = {},
        scopeStack = {}, loops = {},
    }, self)
    for _, arg in ipairs(node.args or {}) do
        if arg.kind == 'VarargExpression' then
            compiler.proto.vararg = true
        else
            compiler.proto.params[#compiler.proto.params + 1] = {
                compiler:localRegister(arg.scope, arg.id),
                compiler:isCaptured(arg.scope, arg.id),
            }
        end
    end
    return compiler
end

function Compiler:emit(op, ...)
    assert(opcodes[op], 'Unknown VM instruction: ' .. tostring(op))
    local code = self.proto.code
    code[#code + 1] = {opcodes[op], ...}
    return #code
end

function Compiler:position()
    return #self.proto.code + 1
end

function Compiler:patch(index, operand, value)
    self.proto.code[index][operand + 1] = value
end

function Compiler:alloc()
    local register = table.remove(self.freeRegisters)
    if not register then
        register = self.proto.maxRegister + 1
        self.proto.maxRegister = register
    end
    assert(not self.registers[register], 'Register already allocated')
    self.registers[register] = 'temporary'
    return register
end

function Compiler:free(register)
    assert(self.registers[register] == 'temporary', 'Cannot release register ' .. tostring(register))
    self:emit('CLEAR', register)
    self.registers[register] = nil
    self.freeRegisters[#self.freeRegisters + 1] = register
end

function Compiler:localRegister(scope, id)
    assert(self.analysis.owners[scope] == self.owner, 'Local belongs to another function')
    self.locals[scope] = self.locals[scope] or {}
    if not self.locals[scope][id] then
        local register = self:alloc()
        self.registers[register] = 'local'
        self.locals[scope][id] = register
    end
    return self.locals[scope][id]
end

function Compiler:isCaptured(scope, id)
    return not not (self.analysis.captured[scope] and self.analysis.captured[scope][id])
end

function Compiler:constant(value)
    assert(value ~= nil, 'Nil is represented by its own instruction')
    local ids = self.constantIds[type(value)]
    if not ids then ids = {}; self.constantIds[type(value)] = ids end
    -- NaN cannot be a table key; signed zero must not collapse into positive zero.
    local key = value
    if type(value) == 'number' and value == 0 then
        key = 1 / value < 0 and 'negative-zero' or 'positive-zero'
    end
    if value == value and ids[key] then return ids[key] end
    local index = #self.proto.constants + 1
    self.proto.constants[index] = value
    if value == value then ids[key] = index end
    return index
end

function Compiler:load(value)
    local register = self:alloc()
    if value == nil then self:emit('NIL', register)
    elseif type(value) == 'number' and value == 0 and 1 / value < 0 then
        -- Lua 5.1 merges signed-zero literals in one native function's constants.
        -- Materialize the sign with a VM operation so it cannot be lost in emitted data.
        self:emit('LOAD', register, self:constant(0))
        self:emit('NEG', register, register)
    else self:emit('LOAD', register, self:constant(value)) end
    return register
end

function Compiler:capture(scope, id)
    self.upvalues[scope] = self.upvalues[scope] or {}
    local index = self.upvalues[scope][id]
    if index then return index end
    assert(self.parent, 'Unresolved root upvalue')
    local description
    if self.analysis.owners[scope] == self.parent.owner then
        assert(self:isCaptured(scope, id), 'Captured local missing analysis')
        description = {0, self.parent:localRegister(scope, id)}
    else
        description = {1, self.parent:capture(scope, id)}
    end
    index = #self.proto.captures + 1
    self.proto.captures[index] = description
    self.upvalues[scope][id] = index
    return index
end

function Compiler:readVariable(scope, id)
    local register = self:alloc()
    if scope.isGlobal then
        self:emit('GLOBAL', register, self:constant(scope:getVariableName(id)))
    elseif self.analysis.owners[scope] == self.owner then
        self:emit(self:isCaptured(scope, id) and 'GETCELL' or 'MOVE',
            register, self:localRegister(scope, id))
    else self:emit('GETUP', register, self:capture(scope, id)) end
    return register
end

function Compiler:writeVariable(scope, id, source)
    if scope.isGlobal then
        self:emit('SETGLOBAL', self:constant(scope:getVariableName(id)), source)
    elseif self.analysis.owners[scope] == self.owner then
        self:emit(self:isCaptured(scope, id) and 'SETCELL' or 'MOVE',
            self:localRegister(scope, id), source)
    else self:emit('SETUP', self:capture(scope, id), source) end
end

function Compiler:initVariable(scope, id, source)
    self:emit(self:isCaptured(scope, id) and 'CELL' or 'MOVE',
        self:localRegister(scope, id), source or 0)
end

function Compiler:finish(node)
    self:block(node.body)
    self:emit('RETURN0')
    return self.proto
end

function Compiler:functionLiteral(node)
    local child = Compiler:new(self.analysis, node, self)
    local proto = child:finish(node)
    local children = self.proto.children
    children[#children + 1] = proto
    local register = self:alloc()
    self:emit('CLOSURE', register, #children)
    return register
end

function Compiler:compile(ast)
    local compiler = Compiler:new(analyze(ast), ast)
    return optimize(compiler:finish(ast))
end

require('prometheus.vm.expressions')(Compiler)
require('prometheus.vm.statements')(Compiler)
return Compiler

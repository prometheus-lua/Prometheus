-- Compile Lua AST into register instructions and a generated Lua interpreter.
local Step = require('prometheus.step')
local Compiler = require('prometheus.vm.compiler')
local Emit = require('prometheus.vm.emit')
local EncryptOperands = require('prometheus.vm.encrypt_operands')

local Vmify = Step:extend()
Vmify.Name = 'Vmify'
Vmify.Description = 'Compiles functions into register instructions executed by a generated Lua VM.'
Vmify.SettingsDescriptor = {
    -- Encrypts every plain numeric VM operand (register indices, constant
    -- indices, jump targets, call-arity flags) with a keystream chained off
    -- each previously-decrypted operand's own value. Operands exist in
    -- cleartext only transiently, inside the generated interpreter's
    -- registers, while it is actually running; nothing in the emitted data
    -- or source ever holds a decrypted operand or a static per-instruction
    -- key. Must run here, before the instruction stream is scattered into
    -- the emitted literal data by Emit.ast -- by the time any later
    -- pipeline step sees the AST, Vmify's instructions no longer exist as
    -- a walkable array of {opcode, operands...}, only as shuffled table
    -- records, so this cannot be a separate post-Vmify step.
    EncryptOperands = {type = 'boolean', default = false},
}

function Vmify:init() end

function Vmify:apply(ast)
    local proto = Compiler:compile(ast)
    if self.EncryptOperands then
        EncryptOperands.apply(proto)
    end
    return Emit.ast(proto, self.EncryptOperands)
end

return Vmify

-- Compile Lua AST into register instructions and a generated Lua interpreter.
local Step = require('prometheus.step')
local Compiler = require('prometheus.vm.compiler')
local Emit = require('prometheus.vm.emit')

local Vmify = Step:extend()
Vmify.Name = 'Vmify'
Vmify.Description = 'Compiles functions into register instructions executed by a generated Lua VM.'
Vmify.SettingsDescriptor = {}

function Vmify:init() end

function Vmify:apply(ast)
    return Emit.ast(Compiler:compile(ast))
end

return Vmify

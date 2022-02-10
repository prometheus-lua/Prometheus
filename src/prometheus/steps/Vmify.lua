-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- Vmify.lua
--
-- This Script provides a Complex Obfuscation Step that will compile the entire Script to  a fully custom bytecode that does not share it's instructions
-- with lua, making it much harder to crack than other lua obfuscators

local Step = require("prometheus.step");
local OldCompiler = require("prometheus.compiler_old.compiler");
local Compiler = require("prometheus.compiler.compiler");

local Vmify = Step:extend();
Vmify.Description = "This Step will Compile your script into a fully-custom (not a half custom like other lua obfuscators) Bytecode Format and emit a vm for executing it.";
Vmify.Name = "Vmify";

Vmify.SettingsDescriptor = {
	Compiler = {
        type = "enum";
        description = "Which Compiler to use",
        values = {
            "old",
            "new",
        },
        default = "new",
    }
}

function Vmify:init(settings)
	
end

function Vmify:apply(ast)
    -- Create Compiler
	local compiler;
    if(self.Compiler == "old") then
        compiler = OldCompiler:new();
    else
        compiler = Compiler:new();
    end
    -- Compile the Script into a bytecode vm
    return compiler:compile(ast);
end

return Vmify;
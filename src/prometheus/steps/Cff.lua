-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- Cff.lua
--
-- Compile the script into Lua statements executed by a randomized block dispatcher.

local Step = require("prometheus.step");
local Compiler = require("prometheus.cff.compiler");
local flattenVm = require("prometheus.vm.flatten");

local Cff = Step:extend();
Cff.Description = "Flattens control flow into Lua statements executed by a randomized block dispatcher.";
Cff.Name = "Cff";

Cff.SettingsDescriptor = {
    ExcludeVm = {type = "boolean", default = false},
}

function Cff:init(_) end

function Cff:apply(ast)
    if self.ExcludeVm and ast.vmRuntime then
        local compiler = Compiler:new();
        compiler.nativeExpressions = {[ast.vmRuntime] = true};
        if ast.vmData then compiler.nativeExpressions[ast.vmData] = true; end
        local flattened = compiler:compile(ast);
        flattened.vmRuntime = compiler.nativeResults[ast.vmRuntime];
        flattened.vmData = compiler.nativeResults[ast.vmData];
        return flattened;
    end
    if ast.vmRuntime then
        local flattened = flattenVm(ast);
        if flattened then return flattened; end
    end
	local compiler = Compiler:new();

    return compiler:compile(ast);
end

return Cff;

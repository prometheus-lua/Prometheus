-- Require Prometheus
local Prometheus = require("src.prometheus")

-- Enable Debugging
-- logger.logLevel = logger.LogLevel.Debug;

-- Config Variables - Later passed as Parameters
local noColors    = false; -- Wether Colors in the Console output should be enabled
local noHighlight = false; -- Disable Syntax Highlighting of Outputed Code

-- The Code to Obfuscate
local code = [=[
	if _G.key == "EliasIstCool!" then
		print("unlocked!")
	else
		print("ERROR: Wrong Key!")
	end
	
]=];

--  Enable/Disable Console Colors - this may be needed because cmd.exe and powershell.exe do not support ANSI Color Escape Sequences. The Windows Terminal Application is needed
Prometheus.Colors.enabled = not noColors;

-- Apply Obfuscation Pipeline
local pipeline = Prometheus.Pipeline:new({
	Seed = 0; -- For Using Time as Seed
	VarNamePrefix = ""; -- No Coustom Prefix
});

--[=[
-- "Mangled" for names like this : a, b, c, d, ...
-- "MangledShuffled" is the same except the chars come in a different order - Recomended
-- "Il" for weird names like this : IlIIl1llI11l1  - Recomended to make less readable
-- "Number" for names like this : _1, _2, _3, ...  - Not recomended
pipeline:setNameGenerator("MangledShuffled");

--[[Disabled because: testing]]
-- Compile to coustom Bytecode
pipeline:addStep(pipeline.Steps.Vmify:new({

}))

--[[Disabled because: slow, big code size]]
-- Split Strings Step
pipeline:addStep(pipeline.Steps.SplitStrings:new({
	MinLength = 20,
	MaxLength = 40,
	ConcatenationType = "coustom",
	CoustomFunctionType = "local",
}));

--[[Disabled because: testing]]
-- Put all Constants into a Constants Array
pipeline:addStep(pipeline.Steps.ConstantArray:new({
	StringsOnly = false; -- Only Put Strings into the Constant Array
	LocalWrapperCount = 3;
	LocalWrapperArgCount = 3,
	Shuffle = true,
}));

-- Proxyfy Locals
pipeline:addStep(pipeline.Steps.ProxifyLocals:new({
	
}));


--[[ Disabled because: slow, causes memory Issues
-- Convert Locals to Table
pipeline:addStep(pipeline.Steps.LocalsToTable:new({
	Treshold = 1,
	RemapIndices = true,
}));
]]


-- Wrap in Function Step
pipeline:addStep(pipeline.Steps.WrapInFunction:new({
	Iterations = 1,
}));
]=]


local obfuscated = pipeline:apply(code);


local out;
if(noColors or noHighlight) then
	out = obfuscated;
else
	Prometheus.Logger:log("Applying Syntax Highlighting ...");
	out = Prometheus.highlight(obfuscated, pipeline.luaVersion);
	Prometheus.Logger:log("Highlighting Done!");
end
print("\n" .. out);

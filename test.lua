-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- test.lua
-- This file will Perform tests using all lua files within the tests directory

-- Require Prometheus
local Prometheus = require("src.prometheus")

-- Enable Debugging
-- logger.logLevel = logger.LogLevel.Debug;

-- Config Variables - Later passed as Parameters
local noColors    = false; -- Wether Colors in the Console output should be enabled
local noHighlight = false; -- Disable Syntax Highlighting of Outputed Code
local isWindows = true;    -- Wether the Test are Performed on a Windows or Linux System

-- The Code to Obfuscate
local code = [=[
	
]=];

--  Enable/Disable Console Colors - this may be needed because cmd.exe and powershell.exe do not support ANSI Color Escape Sequences. The Windows Terminal Application is needed
Prometheus.colors.enabled = not noColors;

-- Apply Obfuscation Pipeline
local pipeline = Prometheus.Pipeline:new({
	Seed = 0; -- For Using Time as Seed
	VarNamePrefix = ""; -- No Coustom Prefix
});

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

print("Performing Prometheus Tests ...")

local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen(isWindows and 'dir "'..directory..'" /b' or 'ls -a "'..directory..'"')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function validate(a, b)
	local outa  = "";
	local outb  = "";

	local enva = shallowcopy(getfenv(a));
	local envb = shallowcopy(getfenv(a));

	enva.print = function(...)
		for i, v in ipairs({...}) do
			outa = outa .. tostring(v);
		end
	end
	
	envb.print = function(...)
		for i, v in ipairs({...}) do
			outb = outb .. tostring(v);
		end
	end

	setfenv(a, enva);
	setfenv(b, envb);

	if(not pcall(a)) then error("Expected Reference Program not to Fail!") end
	if(not pcall(b)) then return false, outa, nil end

	return outa == outb, outa, outb
end

local testdir = "./tests/"
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Warn;
for i, filename in ipairs(scandir(testdir)) do
	local path = testdir .. filename;
	local file = io.open(path,"r");

	local code = file:read("*a");
	local obfuscated = pipeline:apply(code);

	local funca = loadstring(code);
	local funcb = loadstring(obfuscated);

	local validated, outa, outb = validate(funca, funcb);

	if not validated then
		print(Prometheus.colors("[FAILED] ", "red") .. filename)
		print("[OUTA]  ",    outa);
		print("[OUTB]  ", outb);
	else
		print(Prometheus.colors("[PASSED] ", "green") .. filename)
	end

	file:close();
end

print("Done!")

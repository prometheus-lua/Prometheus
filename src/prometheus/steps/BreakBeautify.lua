-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- BreakBeautify.lua
--
-- This Script provides an Obfuscation Step, that breaks the script when beautified

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local BreakBeautify = Step:extend();
BreakBeautify.Description = "This Step Breaks your Script when it is beautified. This is only effective when using the new VM.";
BreakBeautify.Name = "Break Beautify";

BreakBeautify.SettingsDescriptor = {

}

function BreakBeautify:init(settings)
	
end

function BreakBeautify:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
	local code = [[
do
    local gmatch = string.gmatch;
    local err = function() error("Beautify Detected!") end;

    local pcallIntact2 = false;
    local pcallIntact = pcall(function()
        pcallIntact2 = true;
    end) and pcallIntact2;
    
    local _1, s1 = pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)
    local m1 = gmatch(tostring(s1), ':(%d*):')()
    local l1 = tonumber(m1)
    
    local _2, s2 = pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)
    local m2 = gmatch(tostring(s2), ':(%d*):')()
    local l2 = m2 and {[tonumber(m2)] = true} or {};
    if not(_1 or _2) and l2[l1] and pcallIntact then else
        repeat 
            return (function()
                while true do
                    l1, l2 = l2, l1;
                    err();
                end
            end)(); 
        until true;
        while true do
            l2 = math.random(1, 6);
            if l2 > 2 then
                l2 = tostring(l1);
            else
                l1 = l2;
            end
        end
        return nil;
    end
end
    ]]

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);

    return ast;
end

return BreakBeautify;
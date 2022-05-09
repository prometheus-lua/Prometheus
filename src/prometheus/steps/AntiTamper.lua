-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- AntiTamper.lua
--
-- This Script provides an Obfuscation Step, that breaks the script, when someone tries to tamper with it.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified. This is only effective when using the new VM.";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug library. (Recommended, however scripts will not work without debug library.)"
    }
}

function AntiTamper:init(settings)
	
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
	local code = "do local valid = true;";
    if self.UseDebug then
        code = code .. [[
            -- Anti Beautify
            local sethook = debug and debug.sethook or function() end;
            local allowedLine = nil;
            local called = 0;
            sethook(function(s, line)
                called = called + 1;
                if allowedLine then
                    if allowedLine ~= line then
                        sethook(error, "l");
                    end
                else
                    allowedLine = line;
                end
            end, "l");
            (function() end)();
            (function() end)();
            sethook();
            if called < 2 then
                valid = false;
            end

            -- Anti Function Hook
            local funcs = {pcall, string.char, debug.getinfo}
            for i = 1, #funcs do
                if debug.getinfo(funcs[i]).what ~= "C" then
                    valid = false;
                end
            end
        ]]
    end
    local string = RandomStrings.randomString();
    code = code .. [[
    -- Anti Beautify
    local function getTraceback()
        local str = (function(arg)
            return debug.traceback(arg)
        end)("]] .. string .. [[");
        return str;
    end
    
    local traceback = getTraceback();
    valid = valid and traceback:sub(1, traceback:find("\n") - 1) == "]] .. string .. [[";
    local iter = traceback:gmatch(":(%d*):");
    local v, c = iter(), 1;
    for i in iter do
        valid = valid and i == v;
        c = c + 1;
    end
    valid = valid and c >= 2;

    local gmatch = string.gmatch;
    local err = function() error("Tamper Detected!") end;

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
    if not(_1 or _2) and l2[l1] and pcallIntact and valid then else
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

    -- Anti Function Arg Hook
    local obj = setmetatable({}, {
        __tostring = err,
    });
    obj[math.random(1, 100)] = obj;
    (function() end)(obj);

    repeat until valid;
    ]]

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);

    return ast;
end

return AntiTamper;
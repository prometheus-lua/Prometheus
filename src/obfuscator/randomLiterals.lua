-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- Library for Creating Random Literals

local Ast = require("obfuscator.ast");
local RandomStrings = require("obfuscator.randomStrings");

local RandomLiterals = {};

function RandomLiterals.String()
    return RandomStrings.randomStringNode();
end

function RandomLiterals.Number()
    return Ast.NumberExpression(math.random(-8388608, 8388607));
end

function RandomLiterals.Any()
    local type = math.random(1, 2);
    if type == 1 then
        return RandomLiterals.String();
    elseif type == 2 then
        return RandomLiterals.Number();
    end
end


return RandomLiterals;
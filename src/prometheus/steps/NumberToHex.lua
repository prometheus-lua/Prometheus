--dont use antitamper with this else wont work
unpack = unpack or table.unpack;
local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util = require("prometheus.util")

local AstKind = Ast.AstKind;

local NumbersToHex = Step:extend();
NumbersToHex.Description = "This Step Converts Number Literals to Hexadecimal Expressions";
NumbersToHex.Name = "Numbers To Hex";

NumbersToHex.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    }
}

function NumbersToHex:init(settings)
    self.ExpressionGenerators = {
        function(val, depth)
            local hex = string.format("0x%X", val)
            if tonumber(hex) ~= val then
                return false
            end
            return Ast.NumberExpression(hex)
        end,
		function(val, depth)
            local hex = string.format("0X%x", val)
            if tonumber(hex) ~= val then
                return false
            end
            return Ast.NumberExpression(hex)
        end
    }
end

function NumbersToHex:CreateHexExpression(val)
    local generators = util.shuffle({unpack(self.ExpressionGenerators)});
    for _, generator in ipairs(generators) do
        local node = generator(val, 0);
        if node then
            return node;
        end
    end
    return Ast.NumberExpression(val)
end

function NumbersToHex:apply(ast)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateHexExpression(node.value)
            end
        end
    end)
end

return NumbersToHex;

unpack = unpack or table.unpack;

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");

local AstKind = Ast.AstKind;

local NumbersToHex = Step:extend();
NumbersToHex.Description = "Converts number literals to hexadecimal representations";
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
end

function NumbersToHex:CreateHexExpression(val)
    local hexLiteral = string.format("0x%X", val);
    return {
        kind = AstKind.NumberExpression,
        value = hexLiteral,
        isConstant = true,
    }
end

function NumbersToHex:apply(ast)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateHexExpression(node.value);
            end
        end
    end)
end

return NumbersToHex;

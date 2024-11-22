local unpack = unpack or table.unpack;

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");

local AstKind = Ast.AstKind;

local NumberToHex = Step:extend();
NumberToHex.Description = "This Step Converts Number Literals to Hexadecimal Expressions";
NumberToHex.Name = "Numbers To Hex";

NumberToHex.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },
    MaxDepth = {
        type = "number",
        default = 10,
        min = 1,
        max = 10,
    },
    MinValue = {
        type = "number",
        default = 0,
        min = -math.huge,
        max = math.huge,
    },
    MaxValue = {
        type = "number",
        default = math.huge,
        min = -math.huge,
        max = math.huge,
    }
}

function NumberToHex:init(settings)
    self.ExpressionGenerators = {
        function(val)
            local w1 = math.random(1, 9e1)
            local w2 = w1
            local newVal = val + w1 - w2
            return Ast.NumberExpression(string.format("0x%X", newVal))
        end,
        function(val)
            local w1 = math.random(1, 9e1)
            local w2 = w1
            local newVal = val - w1 + w2
            return Ast.NumberExpression(string.format("0x%X", newVal))
        end,
    }
end

function NumberToHex:CreateHexExpression(val)
    return Ast.NumberExpression(string.format("0x%X", val))
end

function NumberToHex:apply(ast)
    local function visitNode(node, depth)
        if depth > self.MaxDepth then
            return node
        end

        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                local val = node.value
                if val >= self.MinValue and val <= self.MaxValue then
                    local generator = self.ExpressionGenerators[math.random(1, #self.ExpressionGenerators)]
                    return generator(val)
                end
            end
        end

        if node.kind == AstKind.Expression then
            for _, subNode in ipairs(node.body) do
                visitNode(subNode, depth + 1)
            end
        end

        return node
    end

    visitast(ast, nil, function(node, data)
        return visitNode(node, 1)
    end)
end

return NumberToHex;
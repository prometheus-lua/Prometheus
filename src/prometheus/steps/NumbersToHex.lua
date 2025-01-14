-- Don't use antitamper with this else it won't work
unpack = unpack or table.unpack

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local NumbersToHex = Step:extend()

NumbersToHex.Description, NumbersToHex.Name = "This Step Converts Number Literals to Hexadecimal Expressions", "Numbers To Hex"
NumbersToHex.SettingsDescriptor = { Treshold = { type = "number", default = 1, min = 0, max = 1 } }

function NumbersToHex:init()
    self.ExpressionGenerators = {
        function(val) return Ast.NumberExpression(string.format("0x%X", val)) end,
        function(val) return Ast.NumberExpression(string.format("0X%x", val)) end
    }
end

function NumbersToHex:CreateHexExpression(val)
    for _, gen in ipairs(util.shuffle(self.ExpressionGenerators)) do
        local node = gen(val)
        if tonumber(node.value) == val then
            return node
        end
    end
    return Ast.NumberExpression(val)
end

function NumbersToHex:apply(ast)
    visitast(ast, nil, function(node)
        if node.kind == Ast.AstKind.NumberExpression and math.random() <= self.Treshold then
            return self:CreateHexExpression(node.value)
        end
    end)
end

return NumbersToHex

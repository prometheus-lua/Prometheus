-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- watermark.lua
--
-- This Script Provides the code needed to the Watermark to the Code
-- The Watermark will only be added when Obfuscating
-- When using minification, no Watermark will be added

local Ast = require("obfuscator.ast");
local config = require("config");

local Watermark = {};

function Watermark:new(pipeline)
    local watermark = {
        varname = "l",
        pipeline = pipeline,
    };

    setmetatable(watermark, self);
    self.__index = self;

    return watermark;
end

function Watermark:applyCheck(ast)
    -- TODO: Apply Watermark Check
end

function Watermark:apply(ast)
    table.insert(ast.body.statements, 1, Ast.AssignmentStatement({
                Ast.AssignmentVariable(ast.globalScope:resolve(self.varname))
            },
            {
                Ast.StringExpression(config.Watermark)
            }
        )
    );
end

return Watermark;
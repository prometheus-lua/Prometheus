-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- Watermark.lua
--
-- This Script provides a Simple Obfuscation Step that will add a watermark to the script

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");

local Watermark = Step:extend();
Watermark.Description = "This Step will add a watermark to the script";
Watermark.Name = "Watermark";

Watermark.SettingsDescriptor = {
  Content = {
    name = "Content",
    description = "The Content of the Watermark",
    type = "string",
    default = "This Script is Part of the Prometheus Obfuscator by Levno_710",
  },
}

function Watermark:init(settings)
	
end

function Watermark:apply(ast)
  local body = ast.body;
  if string.len(self.Content) > 0 then
    local watermark = body.scope:addVariable();
    table.insert(body.statements, 1, Ast.LocalVariableDeclaration(body.scope, {watermark}, {Ast.StringExpression(self.Content)}));
  end
end

return Watermark;
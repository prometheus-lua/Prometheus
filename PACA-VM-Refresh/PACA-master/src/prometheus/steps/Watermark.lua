
local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")

local PACAWatermark = Step:extend()

PACAWatermark.Name = "PACA Watermark"
PACAWatermark.Description = "Adds a scoped watermark assignment to the AST"

local DEFAULT_CONTENT = "Protected by PACA"
local DEFAULT_VARIABLE = "_PACA_WATERMARK"

PACAWatermark.SettingsDescriptor = {
    Content = {
        name = "Content",
        description = "Watermark content",
        type = "string",
        default = DEFAULT_CONTENT,
    },
    CustomVariable = {
        name = "Custom Variable",
        description = "Variable used to store the watermark",
        type = "string",
        default = DEFAULT_VARIABLE,
    },
}

local function validateAst(ast)
    assert(type(ast) == "table",
        "PACA Watermark: AST must be a table")
    assert(type(ast.body) == "table",
        "PACA Watermark: AST body is missing")
    assert(type(ast.body.statements) == "table",
        "PACA Watermark: AST statements are missing")
    assert(type(ast.body.scope) == "table",
        "PACA Watermark: body scope is missing")
    assert(type(ast.globalScope) == "table",
        "PACA Watermark: global scope is missing")
end

local function validateSettings(self)
    assert(type(self.Content) == "string",
        "PACA Watermark: Content must be a string")
    assert(type(self.CustomVariable) == "string"
        and self.CustomVariable ~= "",
        "PACA Watermark: CustomVariable must be a non-empty string")
end

local function createWatermarkAssignment(ast, content, variableName)
    local _, variable = ast.globalScope:resolve(variableName)

    assert(variable ~= nil,
        "PACA Watermark: watermark variable could not be resolved")

    local watermarkTarget =
        Ast.AssignmentVariable(ast.globalScope, variable)

    local callbackScope = Scope:new(ast.body.scope)
    callbackScope:addReferenceToHigherScope(ast.globalScope, variable)

    local callbackArgument = callbackScope:addVariable()

    local callbackBody = Ast.Block({
        Ast.AssignmentStatement(
            { watermarkTarget },
            { Ast.VariableExpression(callbackScope, callbackArgument) }
        )
    }, callbackScope)

    local callback = Ast.FunctionLiteralExpression({
        Ast.VariableExpression(callbackScope, callbackArgument)
    }, callbackBody)

    return Ast.PassSelfFunctionCallStatement(
        Ast.StringExpression(content),
        "gsub",
        {
            Ast.StringExpression(".+"),
            callback,
        }
    )
end

function PACAWatermark:init(settings)
    settings = settings or {}

    if self.Content == nil then
        self.Content = DEFAULT_CONTENT
    end

    if self.CustomVariable == nil then
        self.CustomVariable = DEFAULT_VARIABLE
    end
end

function PACAWatermark:apply(ast)
    validateAst(ast)
    validateSettings(self)

    if self.Content == "" then
        return ast
    end

    local statement = createWatermarkAssignment(
        ast,
        self.Content,
        self.CustomVariable
    )

    table.insert(ast.body.statements, 1, statement)

    return ast
end

return PACAWatermark

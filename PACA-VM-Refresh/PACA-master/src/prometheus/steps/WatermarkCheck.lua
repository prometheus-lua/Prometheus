
local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local Watermark = require("prometheus.steps.Watermark")

local PACAWatermarkGuard = Step:extend()

PACAWatermarkGuard.Name = "PACA Watermark Guard"
PACAWatermarkGuard.Description = "Adds a scoped watermark validation guard"

local DEFAULT_CONTENT = "Protected by PACA"
local MIN_RANDOM = 10000000000
local MAX_RANDOM = 100000000000

PACAWatermarkGuard.SettingsDescriptor = {
    Content = {
        name = "Content",
        description = "Expected watermark content",
        type = "string",
        default = DEFAULT_CONTENT,
    },
}

local function assertTable(value, message)
    assert(type(value) == "table", message)
end

local function resolveNameGenerator(generator)
    if type(generator) == "table" then
        generator = generator.generateName
    end

    assert(type(generator) == "function",
        "PACA Watermark Guard: invalid name generator")

    return generator
end

local function generateVariableName(pipeline)
    assertTable(pipeline, "PACA Watermark Guard: missing pipeline")

    local generator = resolveNameGenerator(pipeline.namegenerator)
    local suffix = generator(math.random(MIN_RANDOM, MAX_RANDOM))

    assert(type(suffix) == "string" and #suffix > 0,
        "PACA Watermark Guard: invalid generated name")

    return "_" .. suffix
end

local function validateAst(ast)
    assertTable(ast, "PACA Watermark Guard: missing AST")
    assertTable(ast.body, "PACA Watermark Guard: missing AST body")
    assertTable(ast.body.statements,
        "PACA Watermark Guard: missing statement list")
    assertTable(ast.body.scope,
        "PACA Watermark Guard: missing body scope")
    assertTable(ast.globalScope,
        "PACA Watermark Guard: missing global scope")
end

local function buildGuard(ast, content, variableName)
    local expectedValue = Ast.StringExpression(content)
    local _, resolvedVariable = ast.globalScope:resolve(variableName)

    local actualValue =
        Ast.VariableExpression(ast.globalScope, resolvedVariable)

    local mismatch =
        Ast.NotEqualsExpression(actualValue, expectedValue)

    local guardScope = Scope:new(ast.body.scope)

    local guardBody = Ast.Block({
        Ast.ReturnStatement({})
    }, guardScope)

    return Ast.IfStatement(mismatch, guardBody, {}, nil)
end

function PACAWatermarkGuard:init()
    if type(self.Content) ~= "string" then
        self.Content = DEFAULT_CONTENT
    end

    if self.Content == "" then
        self.Content = DEFAULT_CONTENT
    end

    self.CustomVariable = nil
end

function PACAWatermarkGuard:apply(ast, pipeline)
    validateAst(ast)

    assertTable(pipeline,
        "PACA Watermark Guard: missing pipeline")

    local variableName = generateVariableName(pipeline)

    self.CustomVariable = variableName

    local guardStatement =
        buildGuard(ast, self.Content, variableName)

    table.insert(ast.body.statements, 1, guardStatement)

    pipeline:addStep(Watermark:new(self))

    return ast
end

return PACAWatermarkGuard


local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")

local PACAWrapper = Step:extend()

PACAWrapper.Name = "PACA Wrapper"
PACAWrapper.Description = "Creates bounded nested vararg closure layers"

local MIN_ITERATIONS = 1
local MAX_ITERATIONS = 5
local DEFAULT_ITERATIONS = 2

PACAWrapper.SettingsDescriptor = {
    Iterations = {
        name = "Iterations",
        description = "Number of nested wrapper layers (1-5)",
        type = "number",
        default = DEFAULT_ITERATIONS,
        min = MIN_ITERATIONS,
        max = MAX_ITERATIONS,
    },
}

local function normalizeIterations(value)
    local number = tonumber(value)

    if not number or number ~= number then
        return DEFAULT_ITERATIONS
    end

    number = math.floor(number)

    if number < MIN_ITERATIONS then
        return MIN_ITERATIONS
    end

    if number > MAX_ITERATIONS then
        return MAX_ITERATIONS
    end

    return number
end

local function validateBlock(block, label)
    assert(type(block) == "table",
        "PACA Wrapper: invalid " .. label)

    assert(type(block.scope) == "table",
        "PACA Wrapper: missing scope in " .. label)

    assert(type(block.statements) == "table",
        "PACA Wrapper: missing statements in " .. label)
end

local function createWrapper(innerBlock, parentScope)
    validateBlock(innerBlock, "inner block")

    assert(type(parentScope) == "table",
        "PACA Wrapper: invalid parent scope")

    local wrapperScope = Scope:new(parentScope)

    innerBlock.scope:setParent(wrapperScope)

    local parameters = {
        Ast.VarargExpression(),
    }

    local arguments = {
        Ast.VarargExpression(),
    }

    local functionExpression =
        Ast.FunctionLiteralExpression(parameters, innerBlock)

    local invocation =
        Ast.FunctionCallExpression(functionExpression, arguments)

    local returnStatement =
        Ast.ReturnStatement({ invocation })

    return Ast.Block({
        returnStatement,
    }, wrapperScope)
end

function PACAWrapper:init(settings)
    settings = settings or {}

    local configuredIterations =
        settings.Iterations or self.Iterations

    self.Iterations = normalizeIterations(configuredIterations)
end

function PACAWrapper:apply(ast)
    assert(type(ast) == "table",
        "PACA Wrapper: AST must be a table")

    assert(type(ast.body) == "table",
        "PACA Wrapper: AST body is missing")

    assert(type(ast.globalScope) == "table",
        "PACA Wrapper: global scope is missing")

    validateBlock(ast.body, "root block")

    local currentBlock = ast.body
    local parentScope = ast.globalScope
    local iterations = normalizeIterations(self.Iterations)

    for _ = 1, iterations do
        currentBlock = createWrapper(currentBlock, parentScope)
        parentScope = currentBlock.scope
    end

    ast.body = currentBlock

    return ast
end

return PACAWrapper

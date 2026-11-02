-- Derive lexical metadata from declarations and uses. Symbols are binding
-- identities; scope records and register slots are private lowering metadata.
local Ast = require('prometheus.ast')
local K = Ast.AstKind

local binary = {}
for _, name in ipairs({'Or', 'And', 'LessThan', 'GreaterThan', 'LessThanOrEquals',
    'GreaterThanOrEquals', 'NotEquals', 'Equals', 'StrCat', 'Add', 'Sub', 'Mul',
    'Div', 'Mod', 'Pow'}) do binary[K[name .. 'Expression']] = true end
local compound = {}
for _, name in ipairs({'Add', 'Sub', 'Mul', 'Div', 'Mod', 'Pow', 'Concat'}) do
    compound[K['Compound' .. name .. 'Statement']] = true
end

return function(ast)
    assert(ast.kind == K.TopNode, 'Binding analysis expects a TopNode')
    ast.bindingAnalysis = nil
    local global = {isGlobal = true}
    ast.globalScope = global
    local analysis = {owners = {}, captured = {}, declarations = {}, references = {}, reads = {}, writes = {}}
    local blocks, active, loops = {}, {}, {}
    local expression, statement, block, functionBody

    local function initialize(scope, parent, owner)
        scope.parentScope, scope.level = parent, parent and parent.level + 1 or 0
        scope.children, scope.referenceCounts, scope.variablesFromHigherScopes = {}, {}, {}
        scope.variables, scope.variablesLookup, scope.symbols = {}, {}, {}
        if parent then parent.children[#parent.children + 1] = scope end
        analysis.owners[scope] = owner or scope
    end
    initialize(global)

    local function bind(symbol, node, scope, declared)
        assert(symbol and symbol.kind == 'LocalSymbol', 'Declaration requires a local symbol')
        assert(symbol.name == nil or type(symbol.name) == 'string', 'Local symbol name must be a string')
        assert(not analysis.declarations[symbol], 'Local symbol has multiple declarations: ' .. tostring(symbol.name))
        analysis.declarations[symbol] = node
        local id = #scope.variables + 1
        local name = symbol.name or ('__prometheus_binding_' .. id)
        symbol.scope, symbol.id, symbol.name = scope, id, name
        scope.variables[id], scope.symbols[id], scope.variablesLookup[name] = name, symbol, id
        active[symbol] = true
        declared[#declared + 1] = symbol
        return id
    end

    local function reference(node, scope, owner, readWrite)
        local target, id
        if node.kind == K.GlobalVariableExpression or node.kind == K.AssignmentGlobalVariable
            or (node.kind == K.FunctionDeclaration and not node.symbol) then
            assert(type(node.name) == 'string', 'Global reference requires a name')
            target, id = global, global.variablesLookup[node.name]
            if not id then
                id = #global.variables + 1
                global.variables[id], global.variablesLookup[node.name] = node.name, id
            end
        else
            local symbol = node.symbol
            assert(symbol and active[symbol], 'Local binding is not accessible at this point: ' .. tostring(symbol and symbol.name))
            target, id = symbol.scope, symbol.id
            local refs = analysis.references[symbol] or {}
            refs[#refs + 1], analysis.references[symbol] = node, refs
            local writes = node.kind == K.AssignmentVariable
                or (node.kind == K.FunctionDeclaration and #node.indices == 0)
            local uses = writes and analysis.writes or analysis.reads
            uses[symbol] = uses[symbol] or {}
            uses[symbol][#uses[symbol] + 1] = node
            if writes and readWrite then
                analysis.reads[symbol] = analysis.reads[symbol] or {}
                local reads = analysis.reads[symbol]
                reads[#reads + 1] = node
            end
            if analysis.owners[target] ~= owner then analysis.captured[symbol] = true end
        end
        node.scope, node.id = target, id
        target.referenceCounts[id] = (target.referenceCounts[id] or 0) + 1
        local current = scope
        while current and current ~= target do
            local refs = current.variablesFromHigherScopes[target] or {}
            current.variablesFromHigherScopes[target] = refs
            refs[id] = (refs[id] or 0) + 1
            current = current.parentScope
        end
        assert(current == target, 'Local binding owner is not an enclosing scope')
    end

    local function expressions(list, scope, owner)
        for _, node in ipairs(list or {}) do expression(node, scope, owner) end
    end

    function expression(node, scope, owner, readWrite)
        local kind = node.kind
        if kind == K.VariableExpression or kind == K.AssignmentVariable
            or kind == K.GlobalVariableExpression or kind == K.AssignmentGlobalVariable then
            reference(node, scope, owner, readWrite)
        elseif binary[kind] then
            expression(node.lhs, scope, owner); expression(node.rhs, scope, owner)
        elseif kind == K.NotExpression or kind == K.NegateExpression or kind == K.LenExpression then
            expression(node.rhs, scope, owner)
        elseif kind == K.IndexExpression or kind == K.AssignmentIndexing then
            expression(node.base, scope, owner); expression(node.index, scope, owner)
        elseif kind == K.FunctionCallExpression or kind == K.PassSelfFunctionCallExpression then
            expression(node.base, scope, owner); expressions(node.args, scope, owner)
        elseif kind == K.FunctionLiteralExpression then
            functionBody(node, scope)
        elseif kind == K.TableConstructorExpression then
            for _, entry in ipairs(node.entries) do
                if entry.kind == K.KeyedTableEntry then expression(entry.key, scope, owner) end
                expression(entry.value, scope, owner)
            end
        elseif kind == K.IfElseExpression then
            expression(node.condition, scope, owner); expression(node.true_value, scope, owner)
            for _, branch in ipairs(node.elseifs) do
                expression(branch.condition, scope, owner); expression(branch.value, scope, owner)
            end
            expression(node.false_value, scope, owner)
        else
            assert(kind == K.BooleanExpression or kind == K.NumberExpression or kind == K.StringExpression
                or kind == K.NilExpression or kind == K.VarargExpression, 'Unknown expression kind: ' .. tostring(kind))
        end
    end

    function functionBody(node, parent)
        local savedLoops = loops
        loops = {}
        block(node.body, parent, nil, function(scope, declared)
            for _, arg in ipairs(node.args or {}) do
                if arg.kind ~= K.VarargExpression then
                    arg.id = bind(arg.symbol, arg, scope, declared)
                    arg.scope = scope
                end
            end
        end)
        loops = savedLoops
    end

    function block(node, parent, owner, before, after)
        assert(node and node.kind == K.Block, 'Expected a block')
        assert(not blocks[node], 'A block occurs multiple times in the AST')
        blocks[node] = true
        local scope = {isGlobal = false}
        node.scope = scope
        initialize(scope, parent, owner)
        owner = owner or scope
        local declared = {}
        if before then before(scope, declared) end
        for _, child in ipairs(node.statements) do statement(child, scope, owner, declared) end
        if after then after(scope, owner) end
        for _, symbol in ipairs(declared) do active[symbol] = nil end
    end

    function statement(node, scope, owner, declared)
        local kind = node.kind
        if kind == K.LocalVariableDeclaration then
            expressions(node.expressions, scope, owner)
            node.scope, node.ids = scope, {}
            for i, symbol in ipairs(node.symbols) do node.ids[i] = bind(symbol, node, scope, declared) end
        elseif kind == K.LocalFunctionDeclaration then
            node.id, node.scope = bind(node.symbol, node, scope, declared), scope
            functionBody(node, scope)
        elseif kind == K.FunctionDeclaration then
            reference(node, scope, owner)
            functionBody(node, scope)
        elseif kind == K.AssignmentStatement then
            expressions(node.lhs, scope, owner); expressions(node.rhs, scope, owner)
        elseif compound[kind] then
            expression(node.lhs, scope, owner, true); expression(node.rhs, scope, owner)
        elseif kind == K.ReturnStatement then expressions(node.args, scope, owner)
        elseif kind == K.FunctionCallStatement or kind == K.PassSelfFunctionCallStatement then
            expression(node.base, scope, owner); expressions(node.args, scope, owner)
        elseif kind == K.DoStatement then block(node.body, scope, owner)
        elseif kind == K.IfStatement then
            expression(node.condition, scope, owner); block(node.body, scope, owner)
            for _, branch in ipairs(node.elseifs) do
                expression(branch.condition, scope, owner); block(branch.body, scope, owner)
            end
            if node.elsebody then block(node.elsebody, scope, owner) end
        elseif kind == K.WhileStatement or kind == K.RepeatStatement
            or kind == K.ForStatement or kind == K.ForInStatement then
            node.parentScope = scope
            loops[#loops + 1] = node
            if kind == K.WhileStatement then expression(node.condition, scope, owner)
            elseif kind == K.ForStatement then
                expression(node.initialValue, scope, owner); expression(node.finalValue, scope, owner)
                expression(node.incrementBy, scope, owner)
            elseif kind == K.ForInStatement then expressions(node.expressions, scope, owner) end
            block(node.body, scope, owner, function(inner, locals)
                if kind == K.ForStatement then
                    node.scope, node.id = inner, bind(node.symbol, node, inner, locals)
                elseif kind == K.ForInStatement then
                    node.scope, node.ids = inner, {}
                    for i, symbol in ipairs(node.symbols) do node.ids[i] = bind(symbol, node, inner, locals) end
                end
            end, function(inner)
                if kind == K.RepeatStatement then expression(node.condition, inner, owner) end
            end)
            loops[#loops] = nil
        elseif kind == K.BreakStatement or kind == K.ContinueStatement then
            assert(#loops > 0, 'Loop control outside a loop')
            assert(not node.loop or node.loop == loops[#loops], 'Loop control targets a non-enclosing loop')
            node.loop, node.scope = loops[#loops], scope
        else assert(kind == K.NopStatement, 'Unknown statement kind: ' .. tostring(kind)) end
    end

    functionBody(ast, global)
    ast.bindingAnalysis = analysis
    return analysis
end

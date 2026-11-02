-- Allocate spellings from lexical analysis while preserving symbol identities.
local function renameScope(scope, settings)
    if not scope.isGlobal then
        local forbidden = {}
        for _, keyword in pairs(settings.Keywords) do forbidden[keyword] = true end
        for outer, ids in pairs(scope.variablesFromHigherScopes) do
            for id, count in pairs(ids) do
                if count > 0 then forbidden[outer.variables[id]] = true end
            end
        end
        scope.variablesLookup = {}
        local index, prefix = 0, settings.prefix or ''
        for id, symbol in ipairs(scope.symbols) do
            local original, name = symbol.name
            repeat
                local generated = settings.generateName(index, scope, original)
                name = prefix .. (generated or original)
                index = index + 1
            until not forbidden[name]
            symbol.name, scope.variables[id] = name, name
            scope.variablesLookup[name], forbidden[name] = id, true
        end
    end
    for _, child in ipairs(scope.children) do renameScope(child, settings) end
end

return function(ast, settings)
    assert(ast.bindingAnalysis, 'Name allocation requires binding analysis')
    renameScope(ast.globalScope, settings)
end

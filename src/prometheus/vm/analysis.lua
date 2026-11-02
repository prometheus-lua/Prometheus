-- Adapt the shared lexical analysis to the VM's scope/slot lookup tables.
local analyzeBindings = require('prometheus.bindinganalysis')

return function(ast)
    local bindings = analyzeBindings(ast)
    local analysis = {owners = bindings.owners, captured = {}}
    for symbol in pairs(bindings.captured) do
        local scope, id = symbol.scope, symbol.id
        analysis.captured[scope] = analysis.captured[scope] or {}
        analysis.captured[scope][id] = true
    end
    return analysis
end

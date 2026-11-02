# AST Bindings

The AST represents each local binding with a stable `LocalSymbol`. A symbol is the identity of one declaration; its name can change during transformations, and binding analysis derives its lexical scope and slot. Local reference nodes point to the same symbol, so transforms do not need to keep references synchronized with scope tables.

## Constructing local bindings

Create a symbol for each local declaration, then use that same object for every reference to the binding:

```lua
local Ast = require("prometheus.ast")
local symbol = Ast.LocalSymbol("value")

local declaration = Ast.LocalVariableDeclaration({symbol}, {
	Ast.NumberExpression(10),
})
local reference = Ast.VariableExpression(symbol)
local write = Ast.AssignmentVariable(symbol)
```

`Ast.LocalFunctionDeclaration(symbol, args, body)` and `Ast.FunctionDeclaration(globalReference, indices, args, body)` also accept symbol-based inputs. `Ast.ForStatement(symbol, initial, final, increment, body)` and `Ast.ForInStatement(symbols, expressions, body)` define loop bindings. `Ast.Block(statements)` and `Ast.TopNode(body)` need no scope arguments. Function arguments are local symbols; use `Ast.VarargExpression()` for a vararg argument. The AST constructors that accept an existing scope and numeric ID remain available as compatibility construction adapters for existing generators.

## Globals

Globals are names, not local bindings. Use `Ast.GlobalVariableExpression(name)` for a read and `Ast.AssignmentGlobalVariable(name)` for a write. Analysis fills their compatibility `scope` and `id` fields, while `.name` remains the source-level global name. `Ast.VariableExpression(scope, id)` and `Ast.AssignmentVariable(scope, id)` still act as construction adapters when the supplied scope is global.

## Running binding analysis

`require("prometheus.bindinganalysis")(ast)` rebuilds lexical metadata for a `TopNode` and returns an analysis record. `Parser:parse` runs it before returning, and `Unparser:unparse` runs it before output, so callers using those APIs directly get analyzed ASTs. AST transforms that need metadata before either entry point can invoke the analysis module themselves after making their changes.

Analysis derives the legacy `scope`, `id`, declaration `ids`, and scope reference tables from symbols and tree structure. Treat those fields as compatibility data: do not use them as the identity of a local or manually adjust reference counts, upvalue counts, parent links, or scope levels. For a local reference, `.symbol` is authoritative. Global references use `.name` as their identity.

The returned record exposes `declarations[symbol]`, `references[symbol]`, `reads[symbol]`, `writes[symbol]`, `captured[symbol]`, and `owners[scope]`. Read/write lists describe reference occurrences; declaration initialization is represented by the declaration itself. The pipeline refreshes analysis after each transformation and before renaming, and compiler entry points analyze their inputs.

The unparser preserves existing local names where possible and changes colliding names as needed to preserve binding identity, even when obfuscating renaming has not been requested.

## Visibility and captures

The tree order determines visibility. A local declaration's initializer expressions are analyzed before that declaration becomes active, matching Lua's rule that a local is not visible in its own initializer. Local functions are active while their bodies are analyzed, allowing recursion. Function arguments and loop variables are active in their function or loop body. A reference is valid only while its symbol is active in the enclosing lexical path. References from a nested function are recorded as captures.

Binding analysis does not widen a scope to make a reference valid. If a transform moves a reference outside the symbol's lexical region, it must also restructure the declarations and references so the binding is valid; analysis will report an inaccessible local symbol otherwise.

## Moving and cloning nodes

Moving a complete subtree is safe when it remains within the lexical region of every symbol it uses and the destination preserves the intended declaration order. Re-run binding analysis after structural changes that affect declarations, references, or scope ownership.

Do not place one declaration symbol in two declaration nodes or share the same block object at multiple tree positions. Analysis rejects duplicate symbol declarations and repeated blocks. When cloning code that introduces a new local binding, create a fresh `Ast.LocalSymbol` for the clone and point its cloned references to that new symbol. Reusing the original symbol would make two declarations claim one binding identity. Global nodes can be cloned by name because globals are identified by their string names.

Older transforms may still construct nodes using `scope` and numeric IDs. These adapters are supported for compatibility, but new transforms should create symbols and let binding analysis rebuild derived scope metadata instead of manually wiring references. The old scope-parent and reference mutation methods have been removed. Numeric IDs may change after every analysis; do not retain them across transformations.

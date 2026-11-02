# AST Bindings

The AST identifies each local binding with a stable `LocalSymbol`. A symbol is
the identity of one declaration, independent of its source spelling, lexical
owner, or eventual register slot. Declarations and references point to the same
symbol through the canonical `symbol` or `symbols` field. Transforms should
preserve those identities when moving nodes and create fresh symbols when they
introduce new bindings.

## Constructing local bindings

Create one symbol for each local declaration and reuse it for every read and
write of that binding:

```lua
local Ast = require("prometheus.ast")
local value = Ast.LocalSymbol("value")

local declaration = Ast.LocalVariableDeclaration({value}, {
	Ast.NumberExpression(10),
})
local read = Ast.VariableExpression(value)
local write = Ast.AssignmentVariable(value)
```

The AST constructors are symbol-only. `Ast.LocalFunctionDeclaration(symbol,
args, body)` declares a local function. `Ast.FunctionDeclaration(target,
indices, args, body)` accepts a global reference or a local reference as its
target. `Ast.ForStatement(symbol, initial, final, increment, body)` and
`Ast.ForInStatement(symbols, expressions, body)` define loop bindings.
`Ast.LocalVariableDeclaration(symbols, expressions)` takes symbols in its
first argument. `Ast.Block(statements)` and `Ast.TopNode(body)` take no scope
argument. Function arguments are local reference nodes (or symbols, which the
function constructors convert to reference nodes); use
`Ast.VarargExpression()` for a vararg argument.

Old scope-plus-numeric-ID construction signatures have been removed. Do not
pass scopes or IDs to AST constructors.

## Globals

Globals are identified by their names and have no local symbol. Use
`Ast.GlobalVariableExpression(name)` for a read and
`Ast.AssignmentGlobalVariable(name)` for a write. Their canonical identity is
the node's `name` field.

## Parsing, analysis, and naming

The parser uses temporary `Bindings` environments while it reads source. Those
environments track declaration visibility, disabled names, and lexical lookup
during parsing. They are distinct from the fresh plain scope records later
derived by binding analysis, and are not AST binding identities.

`require("prometheus.bindinganalysis")(ast)` rebuilds derived lexical metadata
from declarations, references, and tree structure. It returns an analysis
record with `declarations[symbol]`, `references[symbol]`, `reads[symbol]`,
`writes[symbol]`, `captured[symbol]`, and `owners[scope]`. It also attaches fresh
plain scope and slot metadata for consumers that need lexical ownership or
lowering locations. That metadata is derived on each analysis pass; it is not
the identity of a binding. The canonical AST identity remains
`node.symbol`/`node.symbols` for locals and `node.name` for globals.

`Parser:parse` analyzes its result before returning. The pipeline refreshes
analysis after transformations, and `Unparser:unparse` analyzes before output.
Transforms that need derived ownership information at another point can call
the analyzer after changing the tree.

`prometheus.names` allocates local names from analyzed metadata. It updates
symbol names while preserving symbol identity and avoids names that would
capture references from nested functions. Name allocation requires a fresh
binding analysis first.

## Visibility and captures

Analysis follows Lua declaration order. A local declaration's initializer is
analyzed before its symbol becomes active, so the local is not visible in its
own initializer. Local functions are active while their bodies are analyzed,
which allows recursion. Function arguments and loop variables are active in
their function or loop body. A reference is valid only while its symbol is
active on the enclosing lexical path. References from nested functions are
recorded as captures.

Analysis does not widen a lexical region to make a reference valid. If a
transform moves a reference outside its symbol's declaration region, it must
also restructure the declarations and references. Otherwise analysis reports
an inaccessible local symbol.

## Moving and cloning nodes

Moving a complete subtree is safe when it remains within the lexical region of
every symbol it uses and the destination preserves declaration order. Re-run
binding analysis after structural changes that affect declarations,
references, or lexical ownership.

Do not place one declaration symbol in two declaration nodes or share the same
block object at multiple tree positions. Analysis rejects duplicate symbol
declarations and repeated blocks. When cloning code that introduces a new
local binding, create a fresh `Ast.LocalSymbol` for the clone and point its
cloned references to that symbol. Reusing the original symbol would make two
declarations claim one identity. Global nodes can be cloned by name.

Lowering backends may attach private slot or scope metadata for their own
implementation. Such fields are derived and backend-specific; AST transforms
must use symbols and must not rely on those fields for binding identity.

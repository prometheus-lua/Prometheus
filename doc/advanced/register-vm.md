# Register VM architecture

`Vmify` compiles the scoped Prometheus AST directly into instructions executed
by a generated Lua interpreter. It does not use `string.dump`, an external Lua
compiler, or `loadstring` to execute the original source.

## Modules

- `vm/analysis.lua`: lexical scope ownership and captured-local analysis.
- `vm/compiler.lua`: function prototypes, constants, registers, and captures.
- `vm/expressions.lua` and `vm/expressions_tables.lua`: expression lowering,
  value lists, calls, branches, and table constructors.
- `vm/calls.lua`: direct-register lowering for fixed-arity calls and returns,
  with packed value-list lowering for general cases.
- `vm/statements.lua`: statements, lexical cleanup, and loop control.
- `vm/optimize.lua`: recursive, conservative basic-block optimizations and
  cleanup batching before emission.
- `vm/opcodes.lua`: semantic instruction IDs.
- `vm/layout.lua`: a per-emission opcode and operand layout.
- `vm/runtime.lua` and `vm/runtime_dispatch.lua`: runtime templates and the
  generated dispatcher, configured for the selected opcode IDs and operand
  positions.
- `vm/runtime_calls.lua`: fixed-arity and packed call, return, and register
  cleanup handlers used by the generated runtime.
- `vm/emit.lua`: instruction encoding, native prototype table literals, and the
  runtime function IIFE.
- `vm/strings.lua`: optional hoisting of generated interpreter string literals
  into an outer initializer.
- `vm/flatten.lua`: the Cff integration for generated VM interpreters.

A prototype contains instructions, constants, child prototypes, parameter
metadata, and capture descriptors. The emitter passes the native prototype
tables as an argument to a runtime function IIFE. The generated interpreter
then uses that table data; the prototypes are not encoded as strings.

Each invocation owns its register table; vararg functions also carry a counted
vararg tuple. Closures retain only
their referenced upvalue cells; leaving a scope detaches its cells without
destroying values shared by live closures. Value lists carry an explicit `n`
so trailing nils survive calls, varargs, table constructors, and returns.
The compiler keeps ordinary scalar values in individual registers. Small calls
and returns pass those registers directly to native Lua instead of first making
a value-list table. Temporary registers are cleared after consumption, and
conditional branches consume their test register on both paths. The optimizer
can combine adjacent register clears into one `CLEARS` instruction; it emits
that batch at the same point in the instruction stream so register lifetimes
remain intact.

Calls with zero to three scalar arguments use `CALL0` through `CALL3`; tail
calls use `TAILCALL0` through `TAILCALL3`. Their handlers invoke the callee
directly with that exact argument count. Fixed returns use `RETURN0` through
`RETURN3`, which return exactly that many values, including nil values in any
position. Calls with four or more arguments, or with an expandable final
argument such as a call or vararg expression, use the packed path. That path
retains an explicit value count so expanded results and trailing nils are
preserved. Multi-result calls likewise use a counted value list when the
caller needs an open result list or more than one fixed result.

For non-vararg prototypes with at most three parameters, runtime startup reads
the incoming values with `select` and avoids constructing an incoming argument
pack. Vararg functions and functions with more parameters retain the packed
initialization path, which also builds the vararg tuple when needed.

## Generation and composition

`Cff` normally flattens control flow throughout its input AST. When it receives
the AST emitted by `Vmify`, a private `vmRuntime` annotation selects a special
path: by default, `vm/flatten.lua` flattens the interpreter function only. The
large native prototype table initialization remains outside the flattened
function, keeping it out of the Cff control structure and jump limits used by
Lua and LuaJIT.

Set `Cff`'s `ExcludeVm` setting to `true` to leave both the generated
interpreter and the native prototype table literal out of flattening. Cff then
flattens the surrounding code, including helpers introduced by intervening
steps such as string decoders or tamper checks. The interpreter remains native
Lua, so its lexical captures continue to share variables with surrounding
closures according to ordinary Lua upvalue semantics.

`cff/native.lua` emits the excluded expressions directly and bridges their
external locals through Cff's shared upvalue cells. Garbage-collected capture
proxies keep those cells alive for native closures; captures are not value
snapshots. The `vmData` annotation identifies the entire prototype initializer,
including its child prototypes.

With the default `ExcludeVm = false` behavior, the special path passes
read-only external lexical helpers through function arguments. This supports
helpers introduced by intervening steps such as `EncryptStrings`. If the
interpreter writes to an external lexical variable, the special path falls
back to ordinary Cff compilation to preserve that write's behavior.

The compiler keeps canonical semantic instruction IDs. The additional fixed
arity and cleanup instructions use the same ID scheme. At emission,
`layout.lua` chooses a permutation of the opcode IDs and a permutation of
operand slots 2 through 5; slot 1 always contains the opcode. The emitter
encodes each instruction with that layout without changing the compiler
prototypes. One layout is shared by the root prototype and all child
prototypes in the emitted chunk.

Before emission, `optimize.lua` visits the root prototype and its children and
applies conservative basic-block-local rewrites. At emission,
`runtime_dispatch.lua` still builds a balanced numeric `if`/`else` decision
tree from the selected opcode IDs. The interpreter reads each operand from its
selected slot, then checks the opcode for an exact ID at each leaf before
running its handler. For the same input, configuration, and Lua runtime, a
fixed pipeline seed reproduces the layout. Different seeds can produce
different layouts.

In Medium, `EncryptStrings` uses `HoistVmStrings = true` after `Vmify`. It moves
the generated interpreter's literal strings into an outer initializer, where
normal string encryption and later `ConstantArray` processing apply. The
initializer decodes them once at startup and binds them to native lexical
locals used by the interpreter, avoiding decoder or wrapper calls on hot
paths. Strings in `vmData` prototype tables remain encrypted by the normal
`EncryptStrings` behavior. `vm/strings.lua` implements this transformation.

Medium then applies `AntiTamper`, `ConstantArray`, and `WrapInFunction`,
followed by `Cff` with `ExcludeVm = true`. The interpreter and prototype table
initializers stay native while Cff flattens the surrounding code and generated
helpers. `NumbersToExpressions` runs after Cff: it adds no helper functions,
and this ordering prevents Cff from virtualizing arithmetic constant
expressions.

`Strong` applies one `Vmify` pass followed by `EncryptStrings`, `AntiTamper`,
and one default `Cff` pass over the generated VM interpreter. It retains the
default `HoistVmStrings = false` and `ExcludeVm = false` settings. `Weak`
retains the standalone `Cff` transformation without the VM.

Runtime compatibility follows the documented
[limitations](../reference/limitations.md). Native debug representation and
exact resource limits are not preserved.

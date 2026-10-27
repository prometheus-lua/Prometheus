# Limitations

Scripts that rely on the following behavior may require changes before
obfuscation:

- Replacing a function's environment while it is running, including `module(...)`.
- Lua 5.1's legacy implicit `arg` variable in vararg functions.
- Debug access to original functions, locals, upvalues, source locations, or call stacks.
- Debug hooks or debug-based changes to coroutine environments or primitive metatables.
- Exact tail-call capacity, memory usage, collection timing, or runtime limits.
- Inspection of original bytecode or native runtime layout.

Source code constructed or loaded at runtime is not automatically obfuscated.

## Replacing a running function's environment

Prometheus does not support replacing a function's environment while that
function is running. This includes `setfenv(1, env)`, changing an active
caller with `setfenv(2, env)`, and `setfenv(f, env)` when `f` is currently
executing. Subsequent global reads and writes may still use the environment
from the start of the call.

Lua 5.1's `module(...)` also replaces the calling function's environment,
so calling it from transformed code is subject to the same limitation.
Use explicit module tables instead.

Setting a function's environment before calling it is supported:

```lua
setfenv(f, env)
f()
```

This limitation concerns replacing a running function's environment, not
mutating values in an environment table or changing the thread's default
environment with `setfenv(0, env)`.

## Legacy implicit `arg` table

Prometheus does not support Lua 5.1's legacy compatibility behavior that creates
an implicit local `arg` table in vararg functions, or an implicit nil `arg`
when the function uses `...` in its body. Minification may preserve this
behavior on a compatible host runtime, but obfuscation does not guarantee it.

Use explicit varargs instead:

```lua
local function pack(...)
    return {n = select('#', ...), ...}
end
```

The explicit `n` preserves the argument count even when arguments contain nils.
Ordinary explicit locals named `arg` and the CLI's global argument table are
unaffected by this limitation.

## Debug introspection and mutation

Obfuscation changes functions, locals, upvalues, source text, and call stacks.
Compatibility with the original program's debug representation is unsupported.
In particular, do not rely on:

- `debug.getinfo` returning original source names, function names, or line numbers.
- Debug local and upvalue access or mutation referring to the original variables,
  including after a function is dumped and loaded.
- Tracebacks preserving original stack frames, formatting, or error locations.
- Debug hooks observing the original call, return, line, or instruction sequence.
- `debug.getfenv` or `debug.setfenv` accessing coroutine environments as in the
  original script.
- `debug.setmetatable` changing the behavior of primitive types such as numbers,
  booleans, and nil.

Ordinary table and userdata metatables are supported.

## Exact runtime limits and garbage-collection behavior

Prometheus does not guarantee that transformed code has the same resource
usage, implementation limits, or collection schedule as the original code.
Do not rely on identical:

- Tail-call or method-tail-call stack capacity. Deep tail recursion may exhaust
  the stack after obfuscation.
- String-size and allocation limits, memory usage, or execution timing.
- Parser nesting, local-variable or upvalue limits, or exact diagnostic text.
- Garbage-collector allocation thresholds, step sizes, or step counts.
- Userdata lifetime, finalization order, or the timing of weak-table removal.
- Finalizer resurrection and error behavior during collection or interpreter shutdown.

`collectgarbage`, weak tables, and userdata finalizers are not generally
unsupported, but scripts should not depend on their exact scheduling.

## Bytecode and native runtime layout

Obfuscation does not preserve the original bytecode, instructions, function
layout, or table allocation layout. Scripts or native extensions that inspect
these details cannot assume they match the original program. Dumping a
transformed function produces its transformed representation.

## Code loaded at runtime

Prometheus transforms the source files supplied to it. Source strings or files
loaded later through `loadstring`, `load`, `loadfile`, or `require` execute
through the host interpreter and are not automatically transformed. Obfuscate
those files separately if they also need protection.

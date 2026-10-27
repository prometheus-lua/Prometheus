# Limitations

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

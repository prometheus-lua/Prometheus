# Limitations

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

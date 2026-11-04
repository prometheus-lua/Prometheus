# Presets

Prometheus ships with these preset names in `src/presets.lua`:

- `Minify`
- `Weak`
- `Vmify` (test-oriented helper preset)
- `Medium`
- `Strong`

Use with:

```bash
prometheus-lua --preset Medium ./file.lua
```

## Minify

- no step transforms (`Steps = {}`)
- variable renaming still applies through pipeline settings
- best for size reduction and minimal runtime overhead

## Weak

Steps:

1. `Vmify`
2. `ConstantArray`
3. `WrapInFunction`

## Medium

Steps:

1. `EncryptStrings`
2. `AntiTamper` (`UseDebug = false`)
3. `Vmify`
4. `ConstantArray`
5. `NumbersToExpressions`
6. `WrapInFunction`

## Strong

Steps:

1. `Vmify`
2. `EncryptStrings`
3. `AntiTamper` (`UseDebug = false`)
4. `Vmify`
5. `ConstantArray`
6. `NumbersToExpressions`
7. `WrapInFunction`

## Choosing quickly

- Start with `Medium`.
- Move to `Strong` only after benchmarking your runtime path.
- Use `Minify` when you want readability reduction only through compression/renaming style behavior.


## PACA build notes

The `Medium` and `Strong` presets compile the source into the existing custom VM exactly once. `Strong` performs source-level string and constant transformations before VM compilation; it does not wrap an already-generated VM inside a second VM. This avoids unnecessary compile work and reduces compatibility risk.

The legacy `AntiTamper` step is intentionally excluded from the built-in presets. It contains extensive runtime/environment fingerprint checks that can reject valid Lua/Luau environments and cause false failures. It is not a substitute for server-side authorization or protecting secrets. The browser playground does not download or prepend remote anti-tamper source.

Obfuscation is a deterrent, not a guarantee that client-delivered code cannot be recovered. Test output in the exact target runtime before distribution.

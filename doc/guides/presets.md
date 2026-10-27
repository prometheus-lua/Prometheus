# Presets

Prometheus ships with these preset names in `src/presets.lua`:

- `Minify`
- `Weak`
- `Cff` (standalone control flow flattening)
- `Vmify` (standalone register VM)
- `Medium`
- `Strong`

Use a preset with:

```bash
prometheus-lua --preset Medium ./file.lua
```

## Minify

- no step transforms (`Steps = {}`)
- variable renaming still applies through pipeline settings
- best for size reduction and minimal runtime overhead

## Weak

Steps:

1. `Cff`
2. `ConstantArray`
3. `WrapInFunction`

## Cff

This test-oriented preset runs one `Cff` control flow flattening step.

## Vmify

This test-oriented preset compiles the input to the register VM with one `Vmify` step.

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
4. `Cff`
5. `ConstantArray`
6. `NumbersToExpressions`
7. `WrapInFunction`

In `Strong`, `Vmify` compiles the input first, then `Cff` flattens control flow in the generated VM Lua code. This preset contains one VM pass.

## Choosing quickly

- Start with `Medium`.
- Move to `Strong` only after benchmarking your runtime path.
- Use `Minify` when you want readability reduction only through compression/renaming style behavior.
- Use `Cff` and `Vmify` to exercise either step on its own in a custom pipeline.

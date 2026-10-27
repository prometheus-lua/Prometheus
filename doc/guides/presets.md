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

1. `Vmify`
2. `EncryptStrings` (`HoistVmStrings = true`)
3. `AntiTamper` (`UseDebug = false`)
4. `ConstantArray`
5. `WrapInFunction`
6. `Cff` (`ExcludeVm = true`)
7. `NumbersToExpressions`

`HoistVmStrings` moves interpreter string literals into an outer initializer;
that initializer follows the regular encryption and constant array flow,
decodes the strings once at startup, then binds them to native lexical locals
inside the interpreter. This avoids decoder and wrapper calls on the
interpreter's hot paths. Strings in `vmData` remain encrypted normally.

`Cff` runs after the helper-producing steps, so it flattens their surrounding
code, including string decoder, tamper check, constant array, and wrapper
code. The generated VM interpreter and its native prototype table
initializers remain outside Cff flattening. `NumbersToExpressions` runs after
Cff because it adds no helper functions and keeps arithmetic constant
expressions from being virtualized by Cff.

## Strong

Steps:

1. `Vmify`
2. `EncryptStrings`
3. `AntiTamper` (`UseDebug = false`)
4. `Cff`
5. `ConstantArray`
6. `NumbersToExpressions`
7. `WrapInFunction`

In `Strong`, `Vmify` compiles the input first, then `Cff` flattens control flow in the generated VM Lua code. It keeps the defaults `HoistVmStrings = false` and `ExcludeVm = false`; the preset is unchanged and contains one VM pass.

## Choosing quickly

- Start with `Medium`.
- Move to `Strong` only after benchmarking your runtime path.
- Use `Minify` when you want readability reduction only through compression/renaming style behavior.
- Use `Cff` and `Vmify` to exercise either step on its own in a custom pipeline.

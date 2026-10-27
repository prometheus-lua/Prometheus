# Presets

Prometheus ships with these preset names in `src/presets.lua`:

- `Minify`
- `Weak`
- `Cff` (test-oriented helper preset)
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

1. `Cff`
2. `ConstantArray`
3. `WrapInFunction`

## Medium

Steps:

1. `EncryptStrings`
2. `AntiTamper` (`UseDebug = false`)
3. `Cff`
4. `ConstantArray`
5. `NumbersToExpressions`
6. `WrapInFunction`

## Strong

Steps:

1. `Cff`
2. `EncryptStrings`
3. `AntiTamper` (`UseDebug = false`)
4. `Cff`
5. `ConstantArray`
6. `NumbersToExpressions`
7. `WrapInFunction`

## Choosing quickly

- Start with `Medium`.
- Move to `Strong` only after benchmarking your runtime path.
- Use `Minify` when you want readability reduction only through compression/renaming style behavior.

Preset compositions retain their current behavior in this milestone, with former `Vmify` steps renamed to `Cff`; the test preset is now named `Cff`. `Strong` therefore has two `Cff` passes for now. Its planned future sequence is one real `Vmify` pass followed by `Cff`; no real VM is available in this milestone.

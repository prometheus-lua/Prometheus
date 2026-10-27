# Writing a Custom Config

Prometheus accepts a Lua config file via `--config`.

```bash
prometheus-lua --config ./prometheus.config.lua ./input.lua
```

## File format

The config file must be executable Lua code that returns a table:

```lua
return {
  LuaVersion = "Lua51",
  PrettyPrint = false,
  VarNamePrefix = "",
  NameGenerator = "MangledShuffled",
  Seed = 0,
  Steps = {
    { Name = "EncryptStrings", Settings = {} },
    { Name = "Cff", Settings = {} },
    { Name = "WrapInFunction", Settings = { Iterations = 1 } },
  }
}
```

## Step ordering matters

`Steps` are applied in order. The same step can appear multiple times.

`Cff` performs control flow flattening. `ControlFlowFlattening` is also accepted as an alias for `Cff`. `Vmify` compiles the AST into register instructions and data tables, then emits Lua code with an interpreter for that data.

If an existing config used `Name = "Vmify"` for the former control flow flattening behavior, change it to `Name = "Cff"` to keep that behavior. The same `Vmify` key now selects the register VM. The standalone `Cff` and `Vmify` presets are available with `--preset Cff` and `--preset Vmify`.

## Name generator values

Supported string values (from `src/prometheus/namegenerators.lua`):

- `Mangled`
- `MangledShuffled`
- `Il`
- `Number`
- `Confuse`

## Reproducibility

- `Seed > 0`: deterministic RNG seed
- `Seed <= 0`: randomized seed (OpenSSL if available, else current time)

## Common mistakes

- Misspelled step names in `Name`
- wrong setting types (for example string instead of number)
- invalid `VarNamePrefix` for the selected Lua version

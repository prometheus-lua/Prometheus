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

For existing custom configs, replace `Name = "Vmify"` with `Name = "Cff"`.
The `ControlFlowFlattening` constructor key is also accepted. `Vmify` is
reserved for a future real VM step and is not registered in this milestone.
Rename the `Vmify` preset to `Cff` in CLI commands as well.

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

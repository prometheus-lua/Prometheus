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
    { Name = "Vmify", Settings = {} },
    { Name = "WrapInFunction", Settings = { Iterations = 1 } },
  }
}
```

## Step ordering matters

`Steps` are applied in order. The same step can appear multiple times.

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

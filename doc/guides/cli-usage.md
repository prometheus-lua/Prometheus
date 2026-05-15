# CLI Usage

## Entry points

- packaged CLI: `prometheus-lua`
- source CLI: `lua ./cli.lua`

Both call the same CLI implementation (`src/cli.lua`).

## Basic usage

```bash
prometheus-lua --preset Medium ./input.lua
```

## Output file behavior

If `--out` is not provided:

- `input.lua` -> `input.obfuscated.lua`
- `input` -> `input.obfuscated.lua`

## Common workflows

Use a preset:

```bash
prometheus-lua --preset Strong ./src/main.lua
```

Use a custom config file:

```bash
prometheus-lua --config ./prometheus.config.lua ./src/main.lua
```

Force Lua target:

```bash
prometheus-lua --preset Medium --LuaU ./src/main.lua
```

Enable pretty output:

```bash
prometheus-lua --preset Minify --pretty ./src/main.lua
```

## Notes

- Unknown `--...` options are ignored with a warning.
- If no config/preset is passed, Prometheus falls back to `Minify`.
- `update` command uses the official installer script from GitHub.

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
- `input.luau` -> `input.obfuscated.luau`
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
prometheus-lua --preset medium --luau ./src/main.luau
```

Enable pretty output:

```bash
prometheus-lua --preset Minify --pretty ./src/main.lua
```

## Notes

- Command, option, and preset names are case-insensitive; paths preserve their case.
- Options with values accept both `--preset medium` and `--preset=medium`.
- Unknown options and missing option values are errors.
- If no config/preset is passed, Prometheus falls back to `Minify`.
- `update` command uses the official installer script from GitHub.

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

Generate a source map with embedded source text:

```bash
prometheus-lua --preset Medium --out ./output.lua --source-map ./output.lua.map ./src/main.lua
```

Use the map to rewrite a traceback saved in a file:

```bash
prometheus-lua trace --map ./output.lua.map ./traceback.txt
```

`trace` also accepts `-` as the traceback path to read from standard input:

```bash
lua ./output.lua 2>&1 | prometheus-lua trace --map ./output.lua.map -
```

The map embeds the original source by default. To omit it, add
`--source-map-no-sources`; `trace` will then look for source files relative to
the map file and its optional `sourceRoot`. The trace formatter appends source
excerpts around resolved locations. It recognizes Lua `file:line:` locations
and Luau `Script 'file', Line N` locations, while leaving C frames and paths
that do not match the map's generated file unchanged.

If a custom config sets `SourceMap = true`, the CLI writes `<output-file>.map`
by default. Passing `--source-map <path>` overrides that sidecar path.

## Notes

- Unknown `--...` options are ignored with a warning.
- If no config/preset is passed, Prometheus falls back to `Minify`.
- `update` command uses the official installer script from GitHub.
- Source map line mappings are approximate because generated and original
  code do not have a one-to-one line relationship. Compact and pretty output
  can have different unmapped lines; the formatter only maps exact generated
  lines that have a source map segment.
- VM implementation lines use explicit `prometheus-internal://VM/...` source
  labels in the displayed trace. Generated lines without mappings retain their
  generated location.
- `AntiTamper` is skipped when source maps are enabled, with a warning, because
  its generated checks are incompatible with source map output.

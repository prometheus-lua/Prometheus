# Quickstart: First Obfuscation

You can quickly try Prometheus in the [Prometheus Playground](https://prometheus-lua.github.io/Prometheus/). For large scripts or advanced use cases, prefer the CLI workflow below.

Create a simple Lua file:

```lua
print("Hello, World")
```

Run Prometheus from the repository root:

```bash
lua ./cli.lua --preset Medium ./hello.lua
```

Prometheus will write:

- `hello.obfuscated.lua` (default output path)

Run the result with your Lua runtime to validate behavior.

## Important default behavior

- If you do not pass `--preset` or `--config`, Prometheus uses `Minify`.
- `Minify` performs minification only (no obfuscation steps).

## Choosing a preset quickly

- `Weak`: low overhead
- `Medium`: practical default
- `Strong`: strongest built-in preset, highest overhead

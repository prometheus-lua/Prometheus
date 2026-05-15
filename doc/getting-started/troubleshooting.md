# Troubleshooting

## `No Lua runtime found`

This comes from `prometheus-lua` when it cannot find:

1. bundled runtime at `runtime/lua`
2. `luajit`
3. `lua5.1`
4. `lua`

Install one of these runtimes or reinstall with the installer.

## ANSI color output looks broken

Use:

```bash
--nocolors
```

## Parser errors are hard to inspect

Use:

```bash
--saveerrors
```

Prometheus will write `<input>.error.txt` next to your input file.

## `The Step "..." was not found`

Your step `Name` does not match a registered step constructor. Use names documented in [Step Pipeline Overview](../reference/steps/overview.md).

## `PrettyPrint` with `AntiTamper`

`AntiTamper` is skipped when `PrettyPrint = true`. Prometheus logs a warning and continues.

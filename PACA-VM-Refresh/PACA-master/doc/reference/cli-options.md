# CLI Options Reference

## Commands

| Command | Description |
| --- | --- |
| `update` | Runs official installer script to install latest release |
| `--version`, `-v` | Prints version (`PROMETHEUS_LUA_VERSION` or `dev`) |
| `--help`, `-h`, `help` | Prints CLI help |

## Obfuscation options

| Option | Alias | Argument | Description |
| --- | --- | --- | --- |
| `--preset` | `--p` | `<name>` | Use built-in preset by name |
| `--config` | `--c` | `<file>` | Load config Lua file |
| `--out` | `--o` | `<file>` | Output file path |
| `--Lua51` | - | none | Force Lua 5.1 conventions |
| `--LuaU` | - | none | Force LuaU conventions |
| `--pretty` | - | none | Pretty-print generated output |
| `--nocolors` | - | none | Disable ANSI colors |
| `--saveerrors` | - | none | Write parser/runtime errors to `<input>.error.txt` |

## Parsing behavior

- First non-option argument is treated as input file.
- A second non-option argument raises an error.
- Unknown options are ignored with a warning.

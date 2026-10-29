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
| `--lua51` | - | none | Force Lua 5.1 conventions |
| `--luau` | - | none | Force Luau conventions |
| `--pretty` | - | none | Pretty-print generated output |
| `--nocolors` | - | none | Disable ANSI colors |
| `--saveerrors` | - | none | Write parser/runtime errors to `<input>.error.txt` |

## Parsing behavior

- Command names, option names, and built-in preset names are case-insensitive. Existing spellings
  such as `--LuaU` and `--Lua51` continue to work.
- File paths and configuration values retain their original case.
- Options that take a value accept either `--option value` or `--option=value`.
- The first non-option argument is the input file; a second one is an error.
- Use `--` before an input filename beginning with `-`. For an option value
  beginning with `-`, use `--option=value` or a path prefixed with `./`.
- Unknown options, missing values, and values supplied to flags are errors.

# CLI Options Reference

## Commands

| Command | Description |
| --- | --- |
| `update` | Runs official installer script to install latest release |
| `--version`, `-v` | Prints version (`PROMETHEUS_LUA_VERSION` or `dev`) |
| `--help`, `-h`, `help` | Prints CLI help |
| `trace --map <file.map> <traceback.txt>` | Rewrites generated Lua locations using a source map; use `-` instead of a file to read the traceback from standard input |

## Obfuscation options

| Option | Alias | Argument | Description |
| --- | --- | --- | --- |
| `--preset` | `--p` | `<name>` | Use built-in preset by name |
| `--config` | `--c` | `<file>` | Load config Lua file |
| `--out` | `--o` | `<file>` | Output file path |
| `--source-map` | - | `<file.map>` | Write a source map to the specified path; enables source maps for this invocation |
| `--source-map-no-sources` | - | none | Omit embedded original source text from the generated map |
| `--Lua51` | - | none | Force Lua 5.1 conventions |
| `--LuaU` | - | none | Force LuaU conventions |
| `--pretty` | - | none | Pretty-print generated output |
| `--nocolors` | - | none | Disable ANSI colors |
| `--saveerrors` | - | none | Write parser/runtime errors to `<input>.error.txt` |

## Parsing behavior

- First non-option argument is treated as input file.
- A second non-option argument raises an error.
- Unknown options are ignored with a warning.

## Source maps and tracebacks

`--source-map <file.map>` writes a version 3 source map for the generated output.
If source maps are enabled through a config and this option is omitted, the CLI
writes `<output-file>.map`; the explicit option selects a different path.
Original source text is embedded by default so `trace` can show excerpts without
access to the original files. `--source-map-no-sources` omits that text; the
trace command then looks for the original source relative to the map file,
including any `sourceRoot` recorded in the map. The CLI stores relative source
paths relative to the map file so maps remain usable when saved in a subfolder.

For example, save a traceback in a file and translate it with:

```bash
prometheus-lua trace --map ./output.lua.map ./traceback.txt
```

To read the traceback from a pipe or the terminal, pass `-`:

```bash
some-lua-runtime ./output.lua 2>&1 | prometheus-lua trace --map ./output.lua.map -
```

Trace mapping uses the first mapped segment on each exact generated line. It
does not infer mappings for lines without a segment, so compact and pretty
output can have approximate coverage. C frames and unrelated file paths are
left as written. Excerpts show two source lines on either side of each mapped
line where available; missing source files are reported in the output.
VM implementation lines can appear under explicit `prometheus-internal://VM/...`
labels, and generated lines without a mapping remain in the traceback as
generated locations. `AntiTamper` is skipped with a warning when source maps
are enabled because its generated checks are incompatible with source map
output.

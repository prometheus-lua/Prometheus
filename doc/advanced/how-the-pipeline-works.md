# How the Pipeline Works

Execution flow in `Pipeline:apply`:

1. Seed random generator (`Seed` or generated seed)
2. Parse source to AST
3. Apply configured steps in order
4. Rename variables
5. Unparse AST to Lua code

## Seeding details

- If `Seed > 0`: uses that fixed seed.
- Else Prometheus attempts `openssl rand -hex 12` for entropy.
- If OpenSSL is unavailable, it falls back to `os.time()` and logs a warning.

## Variable renaming

After all steps finish, Prometheus renames identifiers using:

- selected `NameGenerator`
- configured `VarNamePrefix`
- language keyword table for selected `LuaVersion`

## Logging

Pipeline emits informational logs for each phase and step timing, including output size relative to source.

## Source maps

Source map generation is disabled by default. Set `SourceMap = true` in a config
to make `Pipeline:apply` return the generated code and map table. Original
source text is embedded by default; set `SourceMapIncludeSources = false` to
omit it.

```lua
local Prometheus = require("src.prometheus")
local config = {
    LuaVersion = "Lua51",
    SourceMap = true,
    SourceMapIncludeSources = true,
    Steps = {},
}

local pipeline = Prometheus.Pipeline:fromConfig(config)
local code, map = pipeline:apply(source, "src/main.lua")
map.file = "main.obfuscated.lua" -- Generated file basename
local mapJson = Prometheus.SourceMap.encode(map)
```

`Prometheus.SourceMap.decode(mapJson)` parses and validates JSON and returns a
map table. `Prometheus.SourceMap.lookup(map, generatedLine)` returns the
original source path, one-based line, and embedded source text when present.
Lookup uses the first mapped segment on that exact generated line; lines with
no mapped segment return `nil`. Source maps retain approximate line locations
where transformations combine or rewrite syntax.

`Prometheus.Traceback.format(traceback, map, mapPath)` rewrites matching Lua
and Luau frames and appends source excerpts around mapped locations. If the map
does not embed source text, it reads source files relative to `mapPath`,
including `sourceRoot` when present. Set `map.file` to the generated output
basename so tracebacks can be matched reliably; the CLI sets this field from
`--out` automatically. When source maps are enabled in a CLI config, the CLI
writes `<output-file>.map` by default; `--source-map <path>` overrides it.

## Parser source locations

`Parser:parse(code, pathOrSourceRecord)` attaches a `sourceSpan` to AST nodes.
The second argument can be a path string or a source record table containing
`path` and `content`; omitting it gives the input a unique internal snippet
label. A span contains a `source` record, `startLine`, `startColumn`, `endLine`,
`endColumn`, `startOffset`, and `endOffset`. Lines and byte columns are
one-based; byte offsets are zero-based and the end offset is exclusive.

```lua
local Parser = require("src.prometheus.parser")
local parser = Parser:new({ LuaVersion = "Lua51" })
local ast = parser:parse(source, {
    path = "src/main.lua",
    content = source,
})
local firstStatementSpan = ast.body.statements[1].sourceSpan
```

Generated snippets use internal paths such as
`prometheus-internal://snippet/1`; these labels distinguish generated source
from user files and can include the snippet text for traceback excerpts.

# Config Object Reference

Prometheus config table fields:

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `LuaVersion` | string | `"Lua51"` (in `fromConfig`) | Target parser/unparser conventions (`Lua51` or `LuaU`) |
| `PrettyPrint` | boolean | `false` | Pretty output mode |
| `SourceMap` | boolean | `false` | Generate a source map and return it as the second result from `Pipeline:apply` |
| `SourceMapIncludeSources` | boolean | `true` | Embed original source text in generated maps when `SourceMap` is enabled |
| `VarNamePrefix` | string | `""` | Prefix for generated variable names |
| `NameGenerator` | string | `"MangledShuffled"` | Name generator key |
| `Seed` | number | `0` | RNG seed; `<=0` means generated seed |
| `Steps` | table | `{}` | Ordered step list |

With `SourceMap = true`, `Pipeline:apply(code, filename)` returns the generated
code and a source map table. `SourceMapIncludeSources` defaults to `true`; set
it to `false` to keep source text out of the map. Maps without embedded sources
can still be used when the original files are available relative to the map
file. In the CLI, a config with `SourceMap = true` writes `<output-file>.map`
unless `--source-map <path>` selects another location.

## Steps format

```lua
Steps = {
  {
    Name = "WrapInFunction",
    Settings = {
      Iterations = 1,
    }
  }
}
```

## Validation behavior

- Unknown step names cause an error.
- Step setting types are validated against each step's descriptor.
- Missing required step settings use defaults when present.

## Setting-name compatibility

Canonical setting names are:

- `Threshold`
- `LocalWrapperThreshold`
- `NumberRepresentationMutation`

Legacy misspellings are still accepted for backward compatibility:

- `Treshold`
- `LocalWrapperTreshold`
- `NumberRepresentationMutaton`

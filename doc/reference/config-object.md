# Config Object Reference

Prometheus config table fields:

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `LuaVersion` | string | `"Lua51"` (in `fromConfig`) | Target parser/unparser conventions (`Lua51` or `LuaU`) |
| `PrettyPrint` | boolean | `false` | Pretty output mode |
| `VarNamePrefix` | string | `""` | Prefix for generated variable names |
| `NameGenerator` | string | `"MangledShuffled"` | Name generator key |
| `Seed` | number | `0` | RNG seed; `<=0` means generated seed |
| `Steps` | table | `{}` | Ordered step list |

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
